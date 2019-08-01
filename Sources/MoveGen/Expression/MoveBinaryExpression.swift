//
//  MoveBinaryExpression.swift
//  MoveGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST
import MoveIR

/// Generates code for a binary expression.
struct MoveBinaryExpression {
  var binaryExpression: BinaryExpression
  var asLValue: Bool

  init(binaryExpression: BinaryExpression, asLValue: Bool = false) {
    self.binaryExpression = binaryExpression
    self.asLValue = asLValue
  }

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
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
    case .plus: return .operation(.add(lhs, rhs))
    case .overflowingPlus: return .operation(.add(lhs, rhs))
    case .minus: return .operation(.subtract(lhs, rhs))
    case .overflowingMinus: return .operation(.overflowingSubtract(lhs, rhs))
    case .times: return .operation(.times(lhs, rhs))
    case .overflowingTimes: return .operation(.times(lhs, rhs))
    case .divide: return .operation(.divide(lhs, rhs))
    case .percent: return .operation(.modulo(lhs, rhs))
    case .closeAngledBracket: return .operation(.greaterThan(lhs, rhs))
    case .openAngledBracket: return .operation(.lessThan(lhs, rhs))
    case .doubleEqual: return .operation(.equal(lhs, rhs))
    case .notEqual: return .operation(.notEqual(lhs, rhs))
    case .or: return .operation(.or(lhs, rhs))
    case .and: return .operation(.and(lhs, rhs))
    case .power: return .operation(.power(lhs, rhs))
    default: fatalError("opToken not supported")
    }
  }
}
