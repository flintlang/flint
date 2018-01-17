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

  func run(passes: [AnyASTPass], in context: Context, compilationContext: CompilationContext) -> ASTPassRunResult {
    var context = context
    var ast = self.ast
    var diagnostics = [Diagnostic]()

    for pass in passes {
      let passContext = ASTPassContext().withUpdates { $0.context = context }
      let result = ASTVisitor(pass: pass).visit(ast, passContext: passContext)
      context = result.passContext.context!
      ast = result.element

      guard !result.diagnostics.isEmpty else { continue }
      diagnostics.append(contentsOf: result.diagnostics)
    }

    return ASTPassRunResult(element: ast, diagnostics: diagnostics)
  }
}

struct ASTPassRunResult {
  var element: TopLevelModule
  var diagnostics: [Diagnostic]
}
