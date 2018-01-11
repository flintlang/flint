//
//  ASTPassRunner.swift
//  flintc
//
//  Created by Franklin Schrans on 1/11/18.
//

import AST
import SemanticAnalyzer
import Diagnostic

struct ASTPassRunner {
  var ast: TopLevelModule

  func run(passes: [ASTPass.Type], in context: Context, compilationContext: CompilationContext) -> ASTPassRunnerOutcome {
    var context = context
    var diagnostics = [Diagnostic]()

    for pass in passes {
      let result = pass.init().run(for: ast, in: context)
      context = result.context

      guard !result.diagnostics.isEmpty else { continue }
      diagnostics.append(contentsOf: result.diagnostics)
    }

    return ASTPassRunnerOutcome(diagnostics: diagnostics)
  }
}

struct ASTPassRunnerOutcome {
  var diagnostics: [Diagnostic]
}
