//
//  ASTPassResult.swift
//  AST
//
//  Created by Franklin Schrans on 1/16/18.
//

import Diagnostic

/// The result of processing an AST node during a pass. The generic type `T` represents the type of the AST node which
/// should be inserted back in the AST.
public struct ASTPassResult<T> {

  /// The diagnostics emitted up to after processing the AST node.
  public var diagnostics: [Diagnostic]

  /// The AST node which should be reinserted in the AST.
  public var element: T

  /// The pass context after visiting the AST node.
  public var passContext: ASTPassContext

  // Allows deleting the current statement
  public var deleteCurrentStatement: Bool

  public init(element: T,
              diagnostics: [Diagnostic],
              passContext: ASTPassContext,
              deleteCurrentStatement: Bool = false) {
    self.element = element
    self.diagnostics = diagnostics
    self.passContext = passContext
    self.deleteCurrentStatement = deleteCurrentStatement
  }

  /// Combines two processings of AST nodes, by merging contexts if required.
  ///
  /// - Parameters:
  ///   - newPassResult: The new other pass result to combine with.
  ///   - mergingContexts: Whether the contexts should be merged.
  /// - Returns: The element type of the new pass result.
  mutating func combining<S>(_ newPassResult: ASTPassResult<S>, mergingContexts: Bool = false) -> S {
    diagnostics.append(contentsOf: newPassResult.diagnostics)
    passContext.storage.merge(newPassResult.passContext.storage, uniquingKeysWith: { _, rhs in
      // Use the newest entry in case both contexts have values for the same key.
      return rhs
    })
    deleteCurrentStatement = deleteCurrentStatement || newPassResult.deleteCurrentStatement
    return newPassResult.element
  }
}
