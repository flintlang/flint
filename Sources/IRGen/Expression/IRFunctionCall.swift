//
//  IRFunctionCall.swift
//  IRGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST

/// Generates code for a function call.
struct IRFunctionCall {
  var functionCall: FunctionCall

  func rendered(functionContext: FunctionContext) -> String {
    let environment = functionContext.environment

    if case .matchedEvent(let eventInformation) =
      environment.matchEventCall(functionCall,
                                 enclosingType: functionContext.enclosingTypeName,
                                 scopeContext: functionContext.scopeContext) {
      return IREventCall(eventCall: functionCall, eventDeclaration: eventInformation.declaration)
        .rendered(functionContext: functionContext)
    }

    let args: String = functionCall.arguments.map({ argument in
      return IRExpression(expression: argument.expression, asLValue: false).rendered(functionContext: functionContext)
    }).joined(separator: ", ")
    let identifier = functionCall.mangledIdentifier ?? functionCall.identifier.name
    return "\(identifier)(\(args))"
  }

}
