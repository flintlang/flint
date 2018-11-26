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

  func rendered(functionContext: FunctionContext) -> ExpressionFragment {
    let functionCall = attemptExpression.functionCall
    let functionName = functionCall.mangledIdentifier ?? functionCall.identifier.name

    let callName: String
    if case .hard = attemptExpression.kind {
      callName = IRWrapperFunction.prefixHard + functionName
    } else {
      callName = IRWrapperFunction.prefixSoft + functionName
    }

    let (preamble, args) = functionCall.arguments.reduce(
      ("", ""), { (r, argument) in
      let (preamble, code) = r
      let e = IRExpression(expression: argument.expression, asLValue: false).rendered(functionContext: functionContext)
      return (preamble + "\n" + e.preamble, code + "\n" + e.expression)
    })

    return ExpressionFragment(pre: preamble, "\(callName)(\(args))")
  }
}
