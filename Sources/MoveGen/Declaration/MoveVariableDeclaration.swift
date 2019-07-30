//
//  MoveVariableDeclaration.swift
//  MoveGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST
import MoveIR

/// Generates code for a variable declaration.
struct MoveVariableDeclaration {
  var variableDeclaration: AST.VariableDeclaration

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
    let allocate = MoveRuntimeFunction.allocateMemory(
      size: functionContext.environment.size(of: variableDeclaration.type.rawType) * EVM.wordSize)
    return .variableDeclaration(VariableDeclaration([(variableDeclaration.identifier.name.mangled, .any)], allocate))
  }
}
