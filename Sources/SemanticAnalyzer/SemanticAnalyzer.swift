//
//  SemanticAnalyzer.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 12/26/17.
//

import AST
import Diagnostic

public struct SemanticAnalyzer {
  public init() {}
  public func run(for ast: TopLevelModule, in context: Context) -> [Diagnostic] {
    let visitor = SemanticAnalyzerVisitor(context: context)
    visitor.visit(ast)
    return visitor.diagnostics
  }
}
