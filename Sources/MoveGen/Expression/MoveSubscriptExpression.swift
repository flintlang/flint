//
//  MoveSubscriptExpression.swift
//  MoveGen
//
//
import AST
import MoveIR

/// Generates code for a subscript expression.
struct MoveSubscriptExpression {
  var subscriptExpression: SubscriptExpression
  var position: Position

  func baseIdentifier(_ baseExpression: AST.Expression) -> AST.Identifier? {
    if case .identifier(let identifier) = baseExpression {
      return identifier
    }
    if case .subscriptExpression(let subscriptExpression) = baseExpression {
      return baseIdentifier(subscriptExpression.baseExpression)
    }
    return nil
  }

  func nestedStorageOffset(subExpr: SubscriptExpression, baseOffset: Int,
                           functionContext: FunctionContext) -> MoveIR.Expression {
    fatalError("Subscript expression has an invalid type")
  }

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
    /* guard let identifier = baseIdentifier(.subscriptExpression(subscriptExpression)),
      let enclosingType = identifier.enclosingType,
      let baseOffset = functionContext.environment.propertyOffset(for: identifier.name,
                                                                  enclosingType: enclosingType) else {
        fatalError("Arrays and dictionaries cannot be defined as local variables yet.")
    } */
    fatalError("Arrays and dictionaries are not supported yet")
  }
}
