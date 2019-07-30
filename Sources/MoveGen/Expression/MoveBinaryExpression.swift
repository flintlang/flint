//
//  MoveBinaryExpression.swift
//  MoveGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST
import YUL

/// Generates code for a binary expression.
struct MoveBinaryExpression {
  var binaryExpression: BinaryExpression
  var asLValue: Bool

  init(binaryExpression: BinaryExpression, asLValue: Bool = false) {
    self.binaryExpression = binaryExpression
    self.asLValue = asLValue
  }

  func rendered(functionContext: FunctionContext) -> YUL.Expression {
    if case .dot = binaryExpression.opToken {
      if case .functionCall(let functionCall) = binaryExpression.rhs {
        return MoveFunctionCall(functionCall: functionCall).rendered(functionContext: functionContext)
      }
      return MovePropertyAccess(lhs: binaryExpression.lhs, rhs: binaryExpression.rhs, asLValue: asLValue)
        .rendered(functionContext: functionContext)
    }

    if case .equal = binaryExpression.opToken {
      return MoveAssignment(lhs: binaryExpression.lhs, rhs: binaryExpression.rhs)
        .rendered(functionContext: functionContext)
    }

    let lhs = MoveExpression(expression: binaryExpression.lhs, asLValue: asLValue)
      .rendered(functionContext: functionContext)
    let rhs = MoveExpression(expression: binaryExpression.rhs, asLValue: asLValue)
      .rendered(functionContext: functionContext)

    switch binaryExpression.opToken {
    case .plus: return MoveRuntimeFunction.add(a: lhs, b: rhs)
    case .overflowingPlus: return .functionCall(FunctionCall("add", lhs, rhs))
    case .minus: return MoveRuntimeFunction.sub(a: lhs, b: rhs)
    case .overflowingMinus: return .functionCall(FunctionCall("sub", lhs, rhs))
    case .times: return MoveRuntimeFunction.mul(a: lhs, b: rhs)
    case .overflowingTimes: return .functionCall(FunctionCall("mul", lhs, rhs))
    case .divide: return MoveRuntimeFunction.div(a: lhs, b: rhs)
    case .percent: return .functionCall(FunctionCall("mod", lhs, rhs))
    case .closeAngledBracket: return .functionCall(FunctionCall("gt", lhs, rhs))
    case .openAngledBracket: return .functionCall(FunctionCall("lt", lhs, rhs))
    case .doubleEqual: return .functionCall(FunctionCall("eq", lhs, rhs))
    case .notEqual: return .functionCall(FunctionCall("iszero", .functionCall(FunctionCall("eq", lhs, rhs))))
    case .or: return .functionCall(FunctionCall("or", lhs, rhs))
    case .and: return .functionCall(FunctionCall("and", lhs, rhs))
    case .power: return MoveRuntimeFunction.power(b: lhs, e: rhs)
    default: fatalError("opToken not supported")
    }
  }
}
