//
//  TopLevelModule.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source

/// A Flint top-level module. Includes top-level declarations, such as contract, struct, and contract behavior
/// declarations.
public struct TopLevelModule: ASTNode {
  public var declarations: [TopLevelDeclaration]

  public init(declarations: [TopLevelDeclaration]) {
    self.declarations = declarations
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    guard let firstTLD = declarations.first,
      let lastTLD = declarations.last else {
        return .INVALID
    }
    return .spanning(firstTLD, to: lastTLD)
  }

  public var description: String {
    return declarations.map({ $0.description }).joined(separator: "\n")
  }
}
