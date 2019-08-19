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
    var preStatements = passContext.preStatements
    var postStatements = passContext.postStatements

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
          let newId = scopeContext.freshIdentifier(sourceLocation: binaryExpression.lhs.sourceLocation)
          let declaration = VariableDeclaration(identifier: newId,
                                                type: Type(inferredType: .inoutType(type),
                                                           identifier: newId))
          preStatements.append(Statement.expression(.binaryExpression(BinaryExpression(
              lhs: .identifier(newId),
              op: Token(kind: .punctuation(.equal), sourceLocation: binaryExpression.op.sourceLocation),
              rhs: binaryExpression.lhs
          ))))
          postStatements.append(Statement.expression(.rawAssembly("release(move(\(newId.name)))", resultType: nil)))
          binaryExpression = BinaryExpression(lhs: .identifier(newId),
                                              op: binaryExpression.op,
                                              rhs: binaryExpression.rhs)
          passContext.scopeContext?.localVariables.append(declaration)
          passContext.functionDeclarationContext?.innerDeclarations.append(declaration)
          passContext.specialDeclarationContext?.innerDeclarations.append(declaration)
        } else if identifier.enclosingType != nil,
                  let enclosingType = passContext.enclosingTypeIdentifier.map({ $0.name }),
                  let type: RawType = passContext.environment?.type(
                      of: binaryExpression.lhs,
                      enclosingType: enclosingType,
                      scopeContext: scopeContext
                  ) {
          // Handle x.y when x is implicitly self.x
          if binaryExpression.opToken == .dot {
            let newId: Identifier
            if let statement: Statement = preStatements.first(where: { (statement: Statement) in
              if case .expression(.binaryExpression(let binary)) = statement,
                 binary.opToken == .equal,
                 case .inoutExpression(let expression) = binary.rhs,
                 expression.expression == binaryExpression.lhs,
                 case .identifier = binary.lhs {
                return true
              }
              return false
            }) {
              guard case .expression(.binaryExpression(let binary)) = statement,
                    case .identifier(let identifier) = binary.lhs else {
                fatalError("Cannot find expected identifier for `\(binaryExpression.lhs)`") 
              }
              newId = identifier
            } else {
              newId = scopeContext.freshIdentifier(sourceLocation: binaryExpression.lhs.sourceLocation)
              let declaration = VariableDeclaration(identifier: newId,
                                                    type: Type(inferredType: .inoutType(type),
                                                               identifier: newId))
              preStatements.append(Statement.expression(.binaryExpression(BinaryExpression(
                  lhs: .identifier(newId),
                  op: Token(kind: .punctuation(.equal), sourceLocation: binaryExpression.op.sourceLocation),
                  rhs: Expression.inoutExpression(InoutExpression(
                      ampersandToken: Token(kind: .punctuation(.ampersand),
                                            sourceLocation: binaryExpression.op.sourceLocation),
                      expression: binaryExpression.lhs
                  ))
              ))))
              postStatements.append(Statement.expression(.rawAssembly("release(move(\(newId.name)))", resultType: nil)))
              passContext.scopeContext?.localVariables.append(declaration)
              passContext.functionDeclarationContext?.innerDeclarations.append(declaration)
              passContext.specialDeclarationContext?.innerDeclarations.append(declaration)
            }

            binaryExpression = BinaryExpression(lhs: .identifier(newId),
                                                op: binaryExpression.op,
                                                rhs: binaryExpression.rhs)
          }
        }
      case .binaryExpression(let binary):
        guard var scopeContext = passContext.scopeContext,
              let enclosingType = passContext.enclosingTypeIdentifier.map({ $0.name }),
              let type: RawType = passContext.environment?.type(
                  of: binaryExpression.lhs,
                  enclosingType: enclosingType,
                  scopeContext: scopeContext
              ) else {
          break
        }
        if binary.opToken == .dot {
          // Handle x.y.z
          let newId = scopeContext.freshIdentifier(sourceLocation: binaryExpression.lhs.sourceLocation)
          let declaration = VariableDeclaration(identifier: newId,
                                                type: Type(inferredType: .inoutType(type),
                                                           identifier: newId))
          preStatements.append(Statement.expression(.binaryExpression(BinaryExpression(
              lhs: .identifier(newId),
              op: Token(kind: .punctuation(.equal), sourceLocation: binaryExpression.op.sourceLocation),
              rhs: Expression.inoutExpression(InoutExpression(
                  ampersandToken: Token(kind: .punctuation(.ampersand),
                                        sourceLocation: binaryExpression.op.sourceLocation),
                  expression: binaryExpression.lhs
              ))
          ))))
          postStatements.append(Statement.expression(.rawAssembly("release(move(\(newId.name)))", resultType: nil)))
          binaryExpression = BinaryExpression(lhs: .identifier(newId),
                                              op: binaryExpression.op,
                                              rhs: binaryExpression.rhs)
          passContext.scopeContext?.localVariables.append(declaration)
          passContext.functionDeclarationContext?.innerDeclarations.append(declaration)
          passContext.specialDeclarationContext?.innerDeclarations.append(declaration)
        }
      default: break
      }
    }

    passContext.preStatements = preStatements
    passContext.postStatements = postStatements
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

/* DEBUGGING
public func postProcess(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
  print(functionCall.identifier.name, functionCall.mangledIdentifier ?? "nil")
  return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
}*/

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

}
