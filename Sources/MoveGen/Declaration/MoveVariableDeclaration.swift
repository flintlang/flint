//
//  MoveVariableDeclaration.swift
//  MoveGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//

import Foundation
import AST
import MoveIR
import Diagnostic

/// Generates code for a variable declaration.
struct MoveVariableDeclaration {
  var variableDeclaration: AST.VariableDeclaration

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
    guard let typeIR: MoveIR.`Type` = CanonicalType(
        from: variableDeclaration.type.rawType,
        environment: functionContext.environment
    )?.render(functionContext: functionContext) else {
      Diagnostics.add(Diagnostic(
          severity: .error,
          sourceLocation: variableDeclaration.sourceLocation,
          message: "Cannot get variable declaration type from \(variableDeclaration.type.rawType)"
      ))
      Diagnostics.displayAndExit()
    }
    guard !variableDeclaration.identifier.isSelf else {
      return .variableDeclaration(MoveIR.VariableDeclaration((MoveSelf.name, typeIR)))
    }
    return .variableDeclaration(MoveIR.VariableDeclaration(
        (variableDeclaration.identifier.name, typeIR)
    ))
  }
}
