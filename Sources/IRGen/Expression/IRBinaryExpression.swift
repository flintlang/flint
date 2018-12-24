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
      let assign = IRAssignment(lhs: binaryExpression.lhs, rhs: binaryExpression.rhs)
        .rendered(functionContext: functionContext)
      return .inline(assign.description)
    }

    let lhs = IRExpression(expression: binaryExpression.lhs, asLValue: asLValue)
      .rendered(functionContext: functionContext)
    let rhs = IRExpression(expression: binaryExpression.rhs, asLValue: asLValue)
      .rendered(functionContext: functionContext)

    let lhsExp = lhs.description
    let rhsExp = rhs.description

    let code: String
    switch binaryExpression.opToken {
    case .plus: code = IRRuntimeFunction.add(a: lhsExp, b: rhsExp)
    case .overflowingPlus: code = "add(\(lhsExp), \(rhsExp))"
    case .minus: code = IRRuntimeFunction.sub(a: lhsExp, b: rhsExp)
    case .overflowingMinus: code = "sub(\(lhsExp), \(rhsExp))"
    case .times: code = IRRuntimeFunction.mul(a: lhsExp, b: rhsExp)
    case .overflowingTimes: code = "mul(\(lhsExp), \(rhsExp))"
    case .divide: code = IRRuntimeFunction.div(a: lhsExp, b: rhsExp)
    case .closeAngledBracket: code = "gt(\(lhsExp), \(rhsExp))"
    case .openAngledBracket: code = "lt(\(lhsExp), \(rhsExp))"
    case .doubleEqual: code = "eq(\(lhsExp), \(rhsExp))"
    case .notEqual: code = "iszero(eq(\(lhsExp), \(rhsExp)))"
    case .or: code = "or(\(lhsExp), \(rhsExp))"
    case .and: code = "and(\(lhsExp), \(rhsExp))"
    case .power: code = IRRuntimeFunction.power(b: lhsExp, e: rhsExp)
    default: fatalError("opToken not supported")
    }

    return .inline(code)
  }
}
