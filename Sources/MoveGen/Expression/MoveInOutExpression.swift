//
//  MoveInOutExpression.swift
//  MoveGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST
import MoveIR

/// Generates code for a binary expression.
struct MoveInOutExpression {
  var expression: InoutExpression
  var position: Position

  init(expression: InoutExpression, position: Position = .normal) {
    self.expression = expression
    self.position = position
  }

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
    // I think .inoutExpression is forcing the type to be .isInout, we need a better way of detecting reference types
    if case .identifier(let identifier) = expression.expression,
       functionContext.isInOut(identifier: identifier) {
      return MoveExpression(expression: expression.expression, position: position)
          .rendered(functionContext: functionContext)
    } else if case .`self` = expression.expression {
      return MoveExpression(expression: expression.expression, position: position)
          .rendered(functionContext: functionContext)
    }
    return .operation(.mutableReference(MoveExpression(expression: expression.expression, position: position)
      .rendered(functionContext: functionContext)))
  }
}
