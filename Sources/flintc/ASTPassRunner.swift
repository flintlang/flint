//
//  ASTPassRunner.swift
//  flintc
//
//  Created by Franklin Schrans on 1/11/18.
//

import AST
import SemanticAnalyzer

struct ASTPassRunner {
  var ast: TopLevelModule

  func run(passes: [ASTPass.Type], in context: Context, compilationContext: CompilationContext) -> ASTPassResult {
    var context = context
    var ast = self.ast
    var diagnostics = [Diagnostic]()

    for pass in passes {
      let result = pass.init().run(for: ast, in: context)
      context = result.context
      ast = result.ast

      guard !result.diagnostics.isEmpty else { continue }
      diagnostics.append(contentsOf: result.diagnostics)
    }

    return ASTPassResult(diagnostics: diagnostics, ast: ast, context: context)
  }
}
