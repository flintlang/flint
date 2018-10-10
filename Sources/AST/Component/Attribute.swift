//
//  Attribute.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source
import Lexer

/// A function attribute, such as `@payable`.
public struct Attribute: ASTNode {

  var kind: Kind
  var atToken: Token
  var identifierToken: Token

  public init?(atToken: Token, identifierToken: Token) {
    guard case .identifier(let attribute) = identifierToken.kind,
      let kind = Kind(rawValue: attribute) else {
        return nil
    }

    self.kind = kind
    self.atToken = atToken
    self.identifierToken = identifierToken
  }

  enum Kind: String {
    case payable
  }

  // MARK: - ASTNode
  public var description: String {
    guard case .identifier(let identifier) = identifierToken.kind else {
      fatalError()
    }
    return "@\(identifier)"
  }
  public var sourceLocation: SourceLocation {
    return .spanning(atToken, to: identifierToken)
  }
}
