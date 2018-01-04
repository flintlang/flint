//
//  SemanticAnalyzer.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 12/26/17.
//

import AST
import Diagnostic

public final class SemanticAnalyzer {
  var ast: TopLevelModule
  var context: Context
  var diagnostics = [Diagnostic]()

  public init(ast: TopLevelModule, context: Context) {
    self.ast = ast
    self.context = context
  }

  public func analyze() -> [Diagnostic] {
    visit(ast)
    return diagnostics
  }

  func addDiagnostic(_ diagnostic: Diagnostic) {
    diagnostics.append(diagnostic)
  }
}
