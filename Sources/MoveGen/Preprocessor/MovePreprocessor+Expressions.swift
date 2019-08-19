//
//  MovePreprocessor+Expressions.swift
//  MoveGen
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

import AST
import Lexer
import Foundation

/// A prepocessing step to update the program's AST before code generation.
extension MovePreprocessor {
  public func process(expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression> {
    var expression = expression
    let environment = passContext.environment!
    var updatedContext = passContext

    if case .binaryExpression(let binaryExpression) = expression {
      if case .dot = binaryExpression.opToken,
         case .identifier(let lhsId) = binaryExpression.lhs,
         case .identifier(let rhsId) = binaryExpression.rhs,
         environment.isEnumDeclared(lhsId.name),
         let matchingProperty = environment.propertyDeclarations(in: lhsId.name)
             .filter({ $0.identifier.identifierToken.kind == rhsId.identifierToken.kind }).first,
         matchingProperty.type!.rawType != .errorType {
        expression = matchingProperty.value!
      }

      if case .equal = binaryExpression.opToken,
         case .variableDeclaration(let variableDeclaration) = binaryExpression.lhs {
        expression = variableDeclaration.assignment(to: binaryExpression.rhs)
        updatedContext.functionDeclarationContext?.innerDeclarations += [variableDeclaration]
        updatedContext.specialDeclarationContext?.innerDeclarations += [variableDeclaration]
        updatedContext.scopeContext?.localVariables += [variableDeclaration]
      }
    }

    return ASTPassResult(element: expression, diagnostics: [], passContext: updatedContext)
  }

  public func process(binaryExpression: BinaryExpression,
                      passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    var passContext = passContext
    var binaryExpression = binaryExpression

    if let op = binaryExpression.opToken.operatorAssignmentOperator {
      let sourceLocation = binaryExpression.op.sourceLocation
      let token = Token(kind: .punctuation(op), sourceLocation: sourceLocation)
      binaryExpression.op = Token(kind: .punctuation(.equal), sourceLocation: sourceLocation)
      binaryExpression.rhs = .binaryExpression(BinaryExpression(lhs: binaryExpression.lhs,
                                                                op: token,
                                                                rhs: binaryExpression.rhs))
    } else if case .dot = binaryExpression.opToken {
      let trail = passContext.functionCallReceiverTrail ?? []
      passContext.functionCallReceiverTrail = trail + [binaryExpression.lhs]

      switch binaryExpression.lhs {
      case .identifier(let identifier):
        guard var scopeContext = passContext.scopeContext else { break }
        if let type = scopeContext.type(for: identifier.name),
           !type.isInout {
          // Handle `x.y` when x is not a reference
          // FIXME cannot currently handle self as cannot tell if has been constructed yet
          binaryExpression.lhs = preAssign(binaryExpression.lhs, passContext: &passContext)
        } else if identifier.enclosingType != nil {
          // Handle x.y when x is implicitly self.x
          if binaryExpression.opToken == .dot {
            binaryExpression.lhs = preAssign(binaryExpression.lhs, passContext: &passContext)
          }
        }
      case .binaryExpression(let binary):
        if binary.opToken == .dot {
          // Handle x.y.z
          binaryExpression.lhs = preAssign(binaryExpression.lhs, passContext: &passContext)
        }
      default: break
      }
    }

    return ASTPassResult(element: binaryExpression,
                         diagnostics: [],
                         passContext: passContext)
  }

  func constructExpression<Expressions: Sequence & RandomAccessCollection>(from expressions: Expressions) -> Expression
      where Expressions.Element == Expression {
    guard expressions.count > 1 else { return expressions.first! }
    let head = expressions.first!
    let tail = expressions.dropFirst()

    let op = Token(kind: .punctuation(.dot), sourceLocation: head.sourceLocation)
    return .binaryExpression(BinaryExpression(lhs: head, op: op, rhs: constructExpression(from: tail)))
  }

  public func process(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    var functionCall = functionCall
    let environment = passContext.environment!
    var receiverTrail = passContext.functionCallReceiverTrail ?? []
    let enclosingType = passContext.enclosingTypeIdentifier!.name
    //let typeStates = passContext.contractBehaviorDeclarationContext?.typeStates ?? []
    let callerProtections = passContext.contractBehaviorDeclarationContext?.callerProtections ?? []
    let isGlobalFunctionCall = self.isGlobalFunctionCall(functionCall, in: passContext)

    let scopeContext = passContext.scopeContext!

    guard !Environment.isRuntimeFunctionCall(functionCall) else {
      // Don't further process runtime functions.
      return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
    }

    if receiverTrail.isEmpty {
      receiverTrail = [.`self`(Token(kind: .`self`, sourceLocation: functionCall.sourceLocation))]
    }

    // Mangle initializer call.
    if environment.isInitializerCall(functionCall) {
      functionCall.mangledIdentifier = mangledFunctionName(for: functionCall, in: passContext)
    } else {
      // Get the result type of the call.
      let declarationEnclosingType: RawTypeIdentifier

      if isGlobalFunctionCall {
        declarationEnclosingType = Environment.globalFunctionStructName
      } else {
        declarationEnclosingType = passContext.environment!.type(of: receiverTrail.last!,
                                                                 enclosingType: enclosingType,
                                                                 callerProtections: callerProtections,
                                                                 scopeContext: scopeContext).name
      }

      // Set the mangled identifier for the function.
      functionCall.mangledIdentifier = mangledFunctionName(for: functionCall, in: passContext)

      // If it returns a dynamic type, pass the receiver as the first parameter.
      let environment = passContext.environment!
      if environment.isStructDeclared(declarationEnclosingType)
             || environment.isContractDeclared(declarationEnclosingType) {
        if !isGlobalFunctionCall {
          var receiver = constructExpression(from: receiverTrail)
          let type: RawType
          switch receiver {
          case .`self`:
            type = scopeContext.type(for: "self")
                ?? environment.type(of: receiver,
                                    enclosingType: passContext.enclosingTypeIdentifier!.name,
                                    scopeContext: scopeContext)
          case .identifier(let identifier):
            type = scopeContext.type(for: identifier.name)
              ?? environment.type(of: receiver,
                                  enclosingType: passContext.enclosingTypeIdentifier!.name,
                                  scopeContext: scopeContext)
          default:
            type = environment.type(of: receiver,
                                    enclosingType: passContext.enclosingTypeIdentifier!.name,
                                    scopeContext: scopeContext)
          }

          if !type.isInout {
            let inoutExpression = InoutExpression(ampersandToken: Token(kind: .punctuation(.ampersand),
                                                                        sourceLocation: receiver.sourceLocation),
                                                  expression: receiver)
            receiver = .inoutExpression(inoutExpression)
          }

          functionCall.arguments.insert(FunctionArgument(receiver), at: 0)
        }
      }
    }

    guard case .failure(let candidates) =
    environment.matchEventCall(functionCall,
                               enclosingType: enclosingType,
                               scopeContext: passContext.scopeContext ?? ScopeContext()),
          candidates.isEmpty else {
      return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
    }

    let passContext = passContext.withUpdates { $0.functionCallReceiverTrail = [] }
    return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
  }

  func mangledFunctionName(for functionCall: FunctionCall, in passContext: ASTPassContext) -> String? {
    // Don't mangle runtime functions
    guard !Environment.isRuntimeFunctionCall(functionCall) else {
      return functionCall.identifier.name
    }

    let environment = passContext.environment!

    let enclosingType: String = functionCall.identifier.enclosingType ?? passContext.enclosingTypeIdentifier!.name

    // Don't mangle event calls
    if case .matchedEvent =
    environment.matchEventCall(functionCall,
                               enclosingType: enclosingType,
                               scopeContext: passContext.scopeContext ?? ScopeContext()) {
      return functionCall.identifier.name
    }

    let typeStates = passContext.contractBehaviorDeclarationContext?.typeStates ?? []
    let callerProtections = passContext.contractBehaviorDeclarationContext?.callerProtections ?? []
    let matchResult = environment.matchFunctionCall(functionCall,
                                                    enclosingType: enclosingType,
                                                    typeStates: typeStates,
                                                    callerProtections: callerProtections,
                                                    scopeContext: passContext.scopeContext!)

    switch matchResult {
    case .matchedFunction(let functionInformation):
      let declaration = functionInformation.declaration
      let parameterTypes = declaration.signature.parameters.rawTypes

      let isContract: Bool
      if let enclosingType = functionCall.identifier.enclosingType {
        isContract = environment.isContractDeclared(enclosingType)
      } else {
        isContract = functionCall.identifier.enclosingType == nil
        && passContext.contractBehaviorDeclarationContext != nil
      }

      return Mangler.mangleFunctionName(declaration.identifier.name,
                                        parameterTypes: parameterTypes,
                                        enclosingType: enclosingType,
                                        isContract: isContract)
    case .matchedFunctionWithoutCaller(let candidates):
      guard candidates.count == 1 else {
        fatalError("Unable to find unique declaration of \(functionCall)")
      }
      guard case .functionInformation(let candidate) = candidates.first! else {
        fatalError("Non-function CallableInformation where function expected")
      }
      let declaration = candidate.declaration
      let parameterTypes = declaration.signature.parameters.rawTypes
      return Mangler.mangleFunctionName(declaration.identifier.name,
                                        parameterTypes: parameterTypes,
                                        enclosingType: enclosingType)
    case .matchedInitializer(let initializerInformation):
      let declaration = initializerInformation.declaration
      let parameterTypes = declaration.signature.parameters.rawTypes
      return Mangler.mangleInitializerName(functionCall.identifier.name, parameterTypes: parameterTypes)
    case .matchedFallback:
      return Mangler.mangleInitializerName(functionCall.identifier.name, parameterTypes: [])
    case .matchedGlobalFunction(let functionInformation):
      let parameterTypes = functionInformation.declaration.signature.parameters.rawTypes
      return Mangler.mangleFunctionName(functionCall.identifier.name,
                                        parameterTypes: parameterTypes,
                                        enclosingType: Environment.globalFunctionStructName)
    case .failure:
      return nil
    }
  }

  func isGlobalFunctionCall(_ functionCall: FunctionCall, in passContext: ASTPassContext) -> Bool {
    let enclosingType = passContext.enclosingTypeIdentifier!.name
    let typeStates = passContext.contractBehaviorDeclarationContext?.typeStates ?? []
    let callerProtections = passContext.contractBehaviorDeclarationContext?.callerProtections ?? []
    let scopeContext = passContext.scopeContext!
    let environment = passContext.environment!

    let match = environment.matchFunctionCall(functionCall,
                                              enclosingType: enclosingType,
                                              typeStates: typeStates,
                                              callerProtections: callerProtections,
                                              scopeContext: scopeContext)

    // Mangle global function
    if case .matchedGlobalFunction = match {
      return true
    }

    return false
  }

  public func postProcess(functionArgument: FunctionArgument,
                          passContext: ASTPassContext) -> ASTPassResult<FunctionArgument> {
    var functionArgument = functionArgument
    var passContext = passContext
    switch functionArgument.expression {
    case .identifier(let identifier):
      // Handle x where x is implicitly self.x
      if identifier.enclosingType != nil {
        functionArgument.expression = preAssign(functionArgument.expression, passContext: &passContext)
      }
    case .binaryExpression(let binary):
      // Handle x.y
      if binary.opToken == .dot {
        functionArgument.expression = preAssign(functionArgument.expression, passContext: &passContext)
      }
    default: break
    }
    return ASTPassResult(element: functionArgument, diagnostics: [], passContext: passContext)
  }

  func preAssign(_ element: Expression, passContext: inout ASTPassContext) -> Expression {
    let newId: Identifier
    if let statement: Statement = passContext.preStatements.first(where: { (statement: Statement) in
      if case .expression(.binaryExpression(let binary)) = statement,
         binary.opToken == .equal,
         case .identifier = binary.lhs {
        if case .inoutExpression(let expression) = binary.rhs,
           expression.expression == element {
          return true
        }
        return binary.rhs == element
      }
      return false
    }) {
      guard case .expression(.binaryExpression(let binary)) = statement,
            case .identifier(let identifier) = binary.lhs else {
        fatalError("Cannot find expected identifier for `\(element)`")
      }
      newId = identifier
    } else {
      guard let environment = passContext.environment,
            var scopeContext = passContext.scopeContext,
            let enclosingType = passContext.enclosingTypeIdentifier?.name else {
        print("Cannot infer type for \(element.sourceLocation)")
        exit(1)
      }
      newId = scopeContext.freshIdentifier(sourceLocation: element.sourceLocation)
      let type = environment.type(of: element,
                                  enclosingType: enclosingType,
                                  scopeContext: scopeContext)
      let declaration: VariableDeclaration
      let assigned: Expression
      if type.isBuiltInType {
        declaration = VariableDeclaration(identifier: newId,
                                          type: Type(inferredType: type,
                                                     identifier: newId))
        assigned = element
      } else {
        declaration = VariableDeclaration(identifier: newId,
                                          type: Type(inferredType: .inoutType(type),
                                                     identifier: newId))
        assigned = .inoutExpression(InoutExpression(
            ampersandToken: Token(kind: .punctuation(.ampersand),
                                  sourceLocation: element.sourceLocation),
            expression: element
        ))
        passContext.postStatements.append(Statement.expression(
            .rawAssembly("release(move(\(Mangler.mangleName(newId.name))))", resultType: nil)
        ))
      }

      passContext.preStatements.append(Statement.expression(.binaryExpression(BinaryExpression(
          lhs: .identifier(newId),
          op: Token(kind: .punctuation(.equal), sourceLocation: element.sourceLocation),
          rhs: assigned
      ))))
      passContext.scopeContext?.localVariables.append(declaration)
      passContext.functionDeclarationContext?.innerDeclarations.append(declaration)
      passContext.specialDeclarationContext?.innerDeclarations.append(declaration)
    }
    return .identifier(newId)
  }
}
