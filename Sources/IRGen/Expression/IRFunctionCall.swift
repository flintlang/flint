//
//  IRFunctionCall.swift
//  IRGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST
import YUL

/// Generates code for a function call.
struct IRFunctionCall {
  var functionCall: AST.FunctionCall

  func rendered(functionContext: FunctionContext) -> YUL.Expression {
    let environment = functionContext.environment
    let enclosingType: RawTypeIdentifier = functionContext.enclosingTypeName
    let scopeContext: ScopeContext = functionContext.scopeContext

    if case .matchedEvent(let eventInformation) =
      environment.matchEventCall(functionCall,
                                 enclosingType: enclosingType,
                                 scopeContext: scopeContext) {
      return IREventCall(eventCall: functionCall, eventDeclaration: eventInformation.declaration)
        .rendered(functionContext: functionContext)
    }

    if case .matchedInitializer(let initializer) =
      environment.matchFunctionCall(functionCall, enclosingType: enclosingType,
                                    typeStates: [], callerProtections: [], scopeContext: scopeContext),
      initializer.declaration.generated {
      return IRExpression(expression: functionCall.arguments[0].expression, asLValue: false)
        .rendered(functionContext: functionContext)
    }

    let args : [YUL.Expression] = functionCall.arguments.map({ argument in
      return IRExpression(expression: argument.expression, asLValue: false).rendered(functionContext: functionContext)
    })

    let identifier = functionCall.mangledIdentifier ?? functionCall.identifier.name
    return .functionCall(YUL.FunctionCall(identifier, args))
  }

}
