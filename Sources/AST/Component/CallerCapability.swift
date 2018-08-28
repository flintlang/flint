//
//  CallerCapability.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source

public struct CallerCapability: ASTNode {
  public var identifier: Identifier

  public var name: String {
    return identifier.name
  }

  public var isAny: Bool {
    return name == "any"
  }

  public init(identifier: Identifier) {
    self.identifier = identifier
  }

  public func isSubCapability(of parent: CallerCapability) -> Bool {
    return parent.isAny || name == parent.name
  }

  // MARK: - ASTNode
  public var description: String {
    return "\(identifier)"
  }
  public var sourceLocation: SourceLocation {
    return identifier.sourceLocation
  }
}
