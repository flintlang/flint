//
//  SemanticAnalyzer.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 12/26/17.
//

import AST

public struct SemanticAnalyzer {
  var ast: TopLevelModule
  var context: Context

  public init(ast: TopLevelModule, context: Context) {
    self.ast = ast
    self.context = context
  }

  public func analyze() throws {
    try visit(ast)
  }
}
