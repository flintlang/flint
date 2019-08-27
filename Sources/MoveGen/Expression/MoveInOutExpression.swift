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
    if case .inoutType = functionContext.environment.type(of: expression.expression,
                                                          enclosingType: functionContext.enclosingTypeName,
                                                          scopeContext: functionContext.scopeContext) {
      if case .`self` = expression.expression,
         functionContext.scopeContext.type(for: "self").map({ $0 == RawType.selfType }) ?? true {
        return .operation(.mutableReference(MoveExpression(expression: expression.expression, position: .inOut)
          .rendered(functionContext: functionContext)))
      }
      return MoveExpression(expression: expression.expression, position: position)
          .rendered(functionContext: functionContext)
    }
    if position != .accessed,
       case .identifier(let identifier) = expression.expression,
       identifier.enclosingType == nil {
      return .operation(.mutableReference(MoveExpression(expression: expression.expression, position: .left)
                                              .rendered(functionContext: functionContext)))
    }
    return .operation(.mutableReference(MoveExpression(expression: expression.expression, position: .inOut)
                                            .rendered(functionContext: functionContext)))
  }
}
