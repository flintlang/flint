//
//  MoveFieldDeclaration.swift
//  flintc
//
//  Created by matteo on 06/08/2019.
//

import AST
import MoveIR

/// Generates code for a variable declaration.
struct MoveFieldDeclaration {
  var variableDeclaration: AST.VariableDeclaration

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
    let typeIR: MoveIR.`Type` = CanonicalType(
        from: variableDeclaration.type.rawType,
        environment: functionContext.environment
    )!.render(functionContext: functionContext)

    return .fieldDeclaration(MoveIR.FieldDeclaration(
      (variableDeclaration.identifier.name, typeIR),
      variableDeclaration.assignedExpression.map { expr in
        MoveExpression(expression: expr).rendered(functionContext: functionContext)
      }
    ))
  }
}
