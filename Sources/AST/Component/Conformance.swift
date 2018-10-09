//
//  Conformance.swift
//  AST
//
//  Created by Hails, Daniel R on 07/09/2018.
//
import Source

public struct Conformance: ASTNode {
  public var identifier: Identifier

  public var name: String {
    return identifier.name
  }

  public init(identifier: Identifier) {
    self.identifier = identifier
  }

  // MARK: - ASTNode
  public var description: String {
    return "\(identifier)"
  }
  public var sourceLocation: SourceLocation {
    return identifier.sourceLocation
  }
}
