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
  public var enclosingType: String?

  public var name: String {
    if case .self = identifierToken.kind {
      return "self"
    }
    guard case .identifier(let name) = identifierToken.kind else { fatalError() }
    return name
  }

  public init(identifierToken: Token) {
    self.identifierToken = identifierToken
  }

  public init(name: String, sourceLocation: SourceLocation) {
    self.identifierToken = Token(kind: .identifier(name), sourceLocation: sourceLocation)
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(name)
    hasher.combine(sourceLocation)
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return identifierToken.sourceLocation
  }

  public var description: String {
    return "\(identifierToken)"
  }
}

public extension Identifier {
  static let DUMMY = Identifier(identifierToken: Token(kind: .identifier(":DUMMY:"), sourceLocation: .DUMMY))
}
