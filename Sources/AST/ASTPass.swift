//
//  ASTPass.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 1/11/18.
//

public protocol ASTPass {
  init()
  func run(for ast: TopLevelModule, in context: Context) -> ASTPassResult
}

public struct ASTPassResult {
  public var diagnostics: [Diagnostic]
  public var ast: TopLevelModule
  public var context: Context

  public init(diagnostics: [Diagnostic], ast: TopLevelModule, context: Context) {
    self.diagnostics = diagnostics
    self.ast = ast
    self.context = context
  }
}

