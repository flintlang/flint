//
//  MoveInOutExpression.swift
//  MoveGen
//
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
    if case .inoutType = functionContext.environment.type(of: expression.expression,
                                                          enclosingType: functionContext.enclosingTypeName,
                                                          scopeContext: functionContext.scopeContext) {
      return MoveExpression(expression: expression.expression, position: position)
          .rendered(functionContext: functionContext)
    } else if position != .accessed,
       case .identifier(let identifier) = expression.expression,
       identifier.enclosingType == nil {
      return .operation(.mutableReference(MoveExpression(expression: expression.expression, position: .left)
                                              .rendered(functionContext: functionContext)))
    } else if case .`self` = expression.expression {
      return MoveExpression(expression: expression.expression, position: position)
          .rendered(functionContext: functionContext)
    }
    return .operation(.mutableReference(MoveExpression(expression: expression.expression, position: .inOut)
                                            .rendered(functionContext: functionContext)))
  }
}
