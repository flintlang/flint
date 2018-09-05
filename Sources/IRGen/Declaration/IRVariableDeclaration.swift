//
//  IRVariableDeclaration.swift
//  IRGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST

/// Generates code for a variable declaration.
struct IRVariableDeclaration {
  var variableDeclaration: VariableDeclaration

  func rendered(functionContext: FunctionContext) -> String {
    let allocate = IRRuntimeFunction.allocateMemory(size: functionContext.environment.size(of: variableDeclaration.type.rawType) * EVM.wordSize)
    return "let \(variableDeclaration.identifier.name.mangled) := \(allocate)"
  }
}
