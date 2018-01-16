//
//  Optimizer.swift
//  Optimizer
//
//  Created by Franklin Schrans on 1/16/18.
//

import Foundation
import AST
import Diagnostic

public struct Optimizer: ASTPass {
  public init() {}

  public func run(for ast: TopLevelModule, in context: Context) -> ASTPassResult {
    let visitor = OptimizerVisitor(context: context)
    let newAST = visitor.visit(ast)
    return ASTPassResult(diagnostics: [], ast: newAST, context: context)
  }
}
