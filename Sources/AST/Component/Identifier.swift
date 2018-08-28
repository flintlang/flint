//
//  Identifier.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source
import Lexer

/// An identifier for a contract, struct, variable, or function.
public struct Identifier: Hashable, ASTNode {
  public var identifierToken: Token
  public var enclosingType: String? = nil

  public var name: String {
    guard case .identifier(let name) = identifierToken.kind else { fatalError() }
    return name
  }

  public init(identifierToken: Token) {
    self.identifierToken = identifierToken
  }

  public init(name: String, sourceLocation: SourceLocation) {
    self.identifierToken = Token(kind: .identifier(name), sourceLocation: sourceLocation)
  }

  public var hashValue: Int {
    return "\(name)_\(sourceLocation)".hashValue
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return identifierToken.sourceLocation
  }

  public var description: String {
    return "\(identifierToken)"
  }
}
