//
//  MoveAttemptExpression.swift
//  MoveGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST
import MoveIR

// Generates code for an attempt expression
struct MoveAttemptExpression {
  var attemptExpression: AttemptExpression

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
    let functionCall = attemptExpression.functionCall
    let functionName = functionCall.mangledIdentifier ?? functionCall.identifier.name

    let callName: String
    if case .hard = attemptExpression.kind {
      callName = MoveWrapperFunction.prefixHard + functionName
    } else {
      callName = MoveWrapperFunction.prefixSoft + functionName
    }

    let args = functionCall.arguments.map({ argument in
      return MoveExpression(expression: argument.expression, position: .normal)
          .rendered(functionContext: functionContext)
    })

    return .functionCall(MoveIR.FunctionCall(callName, args))
  }
}
