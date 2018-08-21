//
//  Attribute.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

/// A function attribute, such as `@payable`.
public struct Attribute: ASTNode {

  var kind: Kind
  var token: Token

  public var description: String {
    return token.kind.description
  }
  public var sourceLocation: SourceLocation {
    return token.sourceLocation
  }

  public init?(token: Token) {
    guard case .attribute(let attribute) = token.kind, let kind = Kind(rawValue: attribute) else { return nil }
    self.kind = kind
    self.token = token
  }

  enum Kind: String {
    case payable
  }
}
