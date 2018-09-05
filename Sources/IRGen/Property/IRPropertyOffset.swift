//
//  IRPropertyOffset.swift
//  IRGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST

/// Generates code for a property offset.
struct IRPropertyOffset {
  var expression: Expression
  var enclosingType: RawType

  func rendered(functionContext: FunctionContext) -> String {
    if case .binaryExpression(let binaryExpression) = expression {
      return IRPropertyAccess(lhs: binaryExpression.lhs, rhs: binaryExpression.rhs, asLValue: true).rendered(functionContext: functionContext)
    } else if case .subscriptExpression(let subscriptExpression) = expression {
      return IRSubscriptExpression(subscriptExpression: subscriptExpression, asLValue: true).rendered(functionContext: functionContext)
    }
    guard case .identifier(let identifier) = expression else { fatalError() }

    let structIdentifier: String

    switch enclosingType {
    case .stdlibType(let type): structIdentifier = type.rawValue
    case .userDefinedType(let type): structIdentifier = type
    default: fatalError()
    }

    return "\(functionContext.environment.propertyOffset(for: identifier.name, enclosingType: structIdentifier)!)"
  }
}
