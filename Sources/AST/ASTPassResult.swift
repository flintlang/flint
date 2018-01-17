//
//  ASTPassResult.swift
//  AST
//
//  Created by Franklin Schrans on 1/16/18.
//

public struct ASTPassResult<T> {
  public var diagnostics: [Diagnostic]
  public var element: T
  public var passContext: ASTPassContext

  public init(element: T, diagnostics: [Diagnostic], passContext: ASTPassContext) {
    self.element = element
    self.diagnostics = diagnostics
    self.passContext = passContext
  }
  
  mutating func mergingDiagnostics<S>(_ otherContext: ASTPassResult<S>) -> S {
    diagnostics.append(contentsOf: otherContext.diagnostics)
    return otherContext.element
  }
}

