//
//  MovePreprocessor+Expressions.swift
//  MoveGen
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

import AST
import Lexer

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
    }

    return ASTPassResult(element: binaryExpression, diagnostics: [], passContext: passContext)
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
    let typeStates = passContext.contractBehaviorDeclarationContext?.typeStates ?? []
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
      // Remove the receiver as the first argument to find the original initializer declaration.
      var initializerWithoutReceiver = functionCall
      if passContext.functionDeclarationContext != nil || passContext.specialDeclarationContext != nil,
        !initializerWithoutReceiver.arguments.isEmpty {
        initializerWithoutReceiver.arguments.remove(at: 0)
      }

      functionCall.mangledIdentifier = mangledFunctionName(for: initializerWithoutReceiver, in: passContext)
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
      if passContext.environment!.isStructDeclared(declarationEnclosingType) {
        if !isGlobalFunctionCall {
          let receiver = constructExpression(from: receiverTrail)
          let inoutExpression = InoutExpression(ampersandToken: Token(kind: .punctuation(.ampersand),
                                                                      sourceLocation: receiver.sourceLocation),
                                                expression: receiver)
          functionCall.arguments.insert(FunctionArgument(.inoutExpression(inoutExpression)), at: 0)
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
    if case .matchedEvent(_) =
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
      return Mangler.mangleFunctionName(declaration.identifier.name,
                                        parameterTypes: parameterTypes,
                                        enclosingType: enclosingType)
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
