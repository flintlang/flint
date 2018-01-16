//
//  SemanticAnalyzer.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 12/26/17.
//

import AST

public struct SemanticAnalyzer: ASTPass {
  public init() {}
  public func run(for ast: TopLevelModule, in context: Context) -> ASTPassResult {
    let visitor = SemanticAnalyzerVisitor(context: context)
    visitor.visit(ast)
    return ASTPassResult(diagnostics: visitor.diagnostics, ast: ast, context: visitor.context)
  }
}
