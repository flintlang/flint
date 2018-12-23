//
//  IRBinaryExpression.swift
//  IRGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST
import YUL

/// Generates code for a binary expression.
struct IRBinaryExpression {
  var binaryExpression: BinaryExpression
  var asLValue: Bool

  init(binaryExpression: BinaryExpression, asLValue: Bool = false) {
    self.binaryExpression = binaryExpression
    self.asLValue = asLValue
  }

  func rendered(functionContext: FunctionContext) -> YUL.Expression {
    if case .dot = binaryExpression.opToken {
      if case .functionCall(let functionCall) = binaryExpression.rhs {
        return IRFunctionCall(functionCall: functionCall).rendered(functionContext: functionContext)
      }
      return IRPropertyAccess(lhs: binaryExpression.lhs, rhs: binaryExpression.rhs, asLValue: asLValue)
        .rendered(functionContext: functionContext)
    }

    if case .equal = binaryExpression.opToken {
      return IRAssignment(lhs: binaryExpression.lhs, rhs: binaryExpression.rhs)
        .rendered(functionContext: functionContext)
    }

    let lhs = IRExpression(expression: binaryExpression.lhs, asLValue: asLValue)
      .rendered(functionContext: functionContext)
    let rhs = IRExpression(expression: binaryExpression.rhs, asLValue: asLValue)
      .rendered(functionContext: functionContext)

    switch binaryExpression.opToken {
    case .plus: return IRRuntimeFunction.add(a: lhs, b: rhs)
    case .overflowingPlus: return .functionCall(FunctionCall("add", [lhs, rhs]))
    case .minus: return IRRuntimeFunction.sub(a: lhs, b: rhs)
    case .overflowingMinus: return .functionCall(FunctionCall("sub", [lhs, rhs]))
    case .times: return IRRuntimeFunction.mul(a: lhs, b: rhs)
    case .overflowingTimes: return .functionCall(FunctionCall("mul", [lhs, rhs]))
    case .divide: return IRRuntimeFunction.div(a: lhs, b: rhs)
    case .closeAngledBracket: return .functionCall(FunctionCall("gt", [lhs, rhs]))
    case .openAngledBracket: return .functionCall(FunctionCall("lt", [lhs, rhs]))
    case .doubleEqual: return .functionCall(FunctionCall("eq", [lhs, rhs]))
    case .notEqual: return .functionCall(FunctionCall("iszero", [.functionCall(FunctionCall("eq", [lhs, rhs]))]))
    case .or: return .functionCall(FunctionCall("or", [lhs, rhs]))
    case .and: return .functionCall(FunctionCall("and", [lhs, rhs]))
    case .power: return IRRuntimeFunction.power(b: lhs, e: rhs)
    default: fatalError("opToken not supported")
    }
  }
}
