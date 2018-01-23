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
  
  mutating func combining<S>(_ otherContext: ASTPassResult<S>, mergingContexts: Bool = false) -> S {
    diagnostics.append(contentsOf: otherContext.diagnostics)
    passContext.storage.merge(otherContext.passContext.storage, uniquingKeysWith: { lhs, rhs in
//      if mergingContexts, let lhs = lhs as? Context, let rhs = rhs as? Context {
//        return lhs.merging(rhs)
//      }
      return rhs
    })

    return otherContext.element
  }
}

