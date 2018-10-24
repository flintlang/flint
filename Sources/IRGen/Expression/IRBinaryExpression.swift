//
//  IRBinaryExpression.swift
//  IRGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST

/// Generates code for a binary expression.
struct IRBinaryExpression {
  var binaryExpression: BinaryExpression
  var asLValue: Bool

  init(binaryExpression: BinaryExpression, asLValue: Bool = false) {
    self.binaryExpression = binaryExpression
    self.asLValue = asLValue
  }

  func rendered(functionContext: FunctionContext) -> String {
    if case .dot = binaryExpression.opToken {
      if case .functionCall(let functionCall) = binaryExpression.rhs {
        return IRFunctionCall(functionCall: functionCall).rendered(functionContext: functionContext)
      }
      return IRPropertyAccess(lhs: binaryExpression.lhs, rhs: binaryExpression.rhs, asLValue: asLValue)
        .rendered(functionContext: functionContext)
    }

    let lhs = IRExpression(expression: binaryExpression.lhs, asLValue: asLValue)
      .rendered(functionContext: functionContext)
    let rhs = IRExpression(expression: binaryExpression.rhs, asLValue: asLValue)
      .rendered(functionContext: functionContext)

    switch binaryExpression.opToken {
    case .equal:
      return IRAssignment(lhs: binaryExpression.lhs, rhs: binaryExpression.rhs)
        .rendered(functionContext: functionContext)

    case .plus: return IRRuntimeFunction.add(a: lhs, b: rhs)
    case .overflowingPlus: return "add(\(lhs), \(rhs))"
    case .minus: return IRRuntimeFunction.sub(a: lhs, b: rhs)
    case .overflowingMinus: return "sub(\(lhs), \(rhs))"
    case .times: return IRRuntimeFunction.mul(a: lhs, b: rhs)
    case .overflowingTimes: return "mul(\(lhs), \(rhs))"
    case .divide: return IRRuntimeFunction.div(a: lhs, b: rhs)
    case .closeAngledBracket: return "gt(\(lhs), \(rhs))"
    case .openAngledBracket: return "lt(\(lhs), \(rhs))"
    case .doubleEqual: return "eq(\(lhs), \(rhs))"
    case .notEqual: return "iszero(eq(\(lhs), \(rhs)))"
    case .or: return "or(\(lhs), \(rhs))"
    case .and: return "and(\(lhs), \(rhs))"
    case .power: return IRRuntimeFunction.power(b: lhs, e: rhs)
    default: fatalError("opToken not supported")
    }
  }
}
