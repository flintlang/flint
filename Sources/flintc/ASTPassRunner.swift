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

  func run(passes: [ASTPass.Type], in context: Context, compilationContext: CompilationContext) throws {
    var errorPasses = [ASTPass.Type]()

    for pass in passes {
      let result = pass.init().run(for: ast, in: context)

      guard !result.diagnostics.isEmpty else { continue }
      print(DiagnosticsFormatter(diagnostics: result.diagnostics, compilationContext: compilationContext).rendered())
      errorPasses.append(pass)
    }

    guard errorPasses.isEmpty else {
      throw Error.passes(errorPasses)
    }
  }

  enum Error: Swift.Error {
    case passes([ASTPass.Type])
  }
}
