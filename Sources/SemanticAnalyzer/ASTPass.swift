//
//  ASTPass.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 1/11/18.
//

import AST
import Diagnostic

public protocol ASTPass {
  init()
  func run(for ast: TopLevelModule, in context: Context) -> ASTPassResult
}

public struct ASTPassResult {
  public var diagnostics: [Diagnostic]
  public var context: Context

  init(diagnostics: [Diagnostic], context: Context) {
    self.diagnostics = diagnostics
    self.context = context
  }
}

