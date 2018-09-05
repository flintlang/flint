//
//  IRAttemptExpression.swift
//  IRGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST

// Generates code for an attempt expression
struct IRAttemptExpression {
  var attemptExpression: AttemptExpression

  func rendered(functionContext: FunctionContext) -> String {
    let functionCall = attemptExpression.functionCall
    let functionName = functionCall.mangledIdentifier ?? functionCall.identifier.name

    let callName: String
    if case .hard = attemptExpression.kind {
      callName = IRWrapperFunction.prefixHard + functionName
    } else {
      callName = IRWrapperFunction.prefixSoft + functionName
    }

    let args: String = functionCall.arguments.map({ argument in
      return IRExpression(expression: argument.expression, asLValue: false).rendered(functionContext: functionContext)
    }).joined(separator: ", ")

    return "\(callName)(\(args))"
  }
}
