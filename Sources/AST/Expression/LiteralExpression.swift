//
//  LiteralExpression.swift
//  AST
//
//  Created by Hails, Daniel R on 22/08/2018.
//
import Source
import Lexer

/// An array literal, such as "[1,2,3]"
public struct ArrayLiteral: ASTNode {
  public var openSquareBracketToken: Token
  public var elements: [Expression]
  public var closeSquareBracketToken: Token

  public init(openSquareBracketToken: Token, elements: [Expression], closeSquareBracketToken: Token) {
    self.openSquareBracketToken = openSquareBracketToken
    self.elements = elements
    self.closeSquareBracketToken = closeSquareBracketToken
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return .spanning(openSquareBracketToken, to: closeSquareBracketToken)
  }

  public var description: String {
    let elementText = elements.map({ $0.description }).joined(separator: ", ")
    return "\(openSquareBracketToken)\(elementText)\(closeSquareBracketToken)"
  }
}

/// A dictionary literal, such as "[1: 2, 3: 4]"
public struct DictionaryLiteral: ASTNode {
  public var openSquareBracketToken: Token
  public var elements: [Entry]
  public var closeSquareBracketToken: Token

  public init(openSquareBracketToken: Token, elements: [Entry], closeSquareBracketToken: Token) {
    self.openSquareBracketToken = openSquareBracketToken
    self.elements = elements
    self.closeSquareBracketToken = closeSquareBracketToken
  }

  public struct Entry: Equatable, CustomStringConvertible {
    var key: Expression
    var value: Expression

    public init(key: Expression, value: Expression) {
      self.key = key
      self.value = value
    }

    public var description: String {
      return "\(key): \(value)"
    }
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return .spanning(openSquareBracketToken, to: closeSquareBracketToken)
  }

  public var description: String {
    let elementText = elements.map({ $0.description }).joined(separator: ", ")
    return "\(openSquareBracketToken)\(elementText)\(closeSquareBracketToken)"
  }
}
