//
//  MovePropertyOffset.swift
//  MoveGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST
import MoveIR

/// Generates code for a property offset.
struct MovePropertyOffset {
  var expression: AST.Expression
  var enclosingType: RawType

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
    if case .binaryExpression(let binaryExpression) = expression {
      return MovePropertyAccess(lhs: binaryExpression.lhs, rhs: binaryExpression.rhs, position: .left)
        .rendered(functionContext: functionContext)
    } else if case .subscriptExpression(let subscriptExpression) = expression {
      return MoveSubscriptExpression(subscriptExpression: subscriptExpression, position: .left)
        .rendered(functionContext: functionContext)
    }
    guard case .identifier(let identifier) = expression else { fatalError() }

    let structIdentifier: String

    switch enclosingType {
    case .userDefinedType(let type): structIdentifier = type
    default: fatalError()
    }

    return .literal(.num(
      functionContext.environment.propertyOffset(for: identifier.name, enclosingType: structIdentifier)!
    ))
  }
}
