//
//  ASTPassRunner.swift
//  flintc
//
//  Created by Franklin Schrans on 1/11/18.
//

import AST
import SemanticAnalyzer

/// Visits an AST using multiple AST passes.
struct ASTPassRunner {
  var ast: TopLevelModule

  func run(passes: [AnyASTPass], in environment: Environment, compilationContext: CompilationContext) -> ASTPassRunResult {
    var environment = environment
    var ast = self.ast
    var diagnostics = [Diagnostic]()

    for pass in passes {
      // Runs each pass, passing along the enviroment built at the previous pass.

      let passContext = ASTPassContext().withUpdates { $0.environment = environment }
      let result = ASTVisitor(pass: pass).visit(ast, passContext: passContext)
      environment = result.passContext.environment!
      ast = result.element

      guard !result.diagnostics.isEmpty else { continue }
      diagnostics.append(contentsOf: result.diagnostics)
    }

    return ASTPassRunResult(element: ast, diagnostics: diagnostics, environment: environment)
  }
}

/// The result after running a sequence of AST passes.
struct ASTPassRunResult {
  var element: TopLevelModule
  var diagnostics: [Diagnostic]
  var environment: Environment
}
