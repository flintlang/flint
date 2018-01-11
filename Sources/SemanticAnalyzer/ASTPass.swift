//
//  ASTPass.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 1/11/18.
//

import AST
import Diagnostic

public protocol ASTPass {
  func run(for ast: TopLevelModule, in context: Context) -> ASTPassResult
  init()
}

public struct ASTPassResult {
  public var diagnostics: [Diagnostic]

  init(diagnostics: [Diagnostic]) {
    self.diagnostics = diagnostics
  }
}

