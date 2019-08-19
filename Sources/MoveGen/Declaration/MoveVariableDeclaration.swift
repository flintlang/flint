//
//  MoveVariableDeclaration.swift
//  MoveGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//

import Foundation
import AST
import MoveIR

/// Generates code for a variable declaration.
struct MoveVariableDeclaration {
  var variableDeclaration: AST.VariableDeclaration

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
    guard let typeIR: MoveIR.`Type` = CanonicalType(
        from: variableDeclaration.type.rawType,
        environment: functionContext.environment
    )?.render(functionContext: functionContext) else {
      print("""
            Cannot get variable declaration type from \(variableDeclaration.type.rawType) \
            at position \(variableDeclaration.sourceLocation).

            flintc internal error located at \(#file):\(#line)
            """)
      exit(1)
    }
    guard !variableDeclaration.identifier.isSelf else {
      return .variableDeclaration(MoveIR.VariableDeclaration((MoveSelf.name, typeIR)))
    }
    return .variableDeclaration(MoveIR.VariableDeclaration(
        (variableDeclaration.identifier.name, typeIR)
    ))
  }
}
