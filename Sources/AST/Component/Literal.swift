//
//  Literal.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

/// An array literal, such as "[1,2,3]"
public struct ArrayLiteral: SourceEntity {
  public var openSquareBracketToken: Token
  public var elements: [Expression]
  public var closeSquareBracketToken: Token

  public var sourceLocation: SourceLocation {
    return .spanning(openSquareBracketToken, to: closeSquareBracketToken)
  }

  public init(openSquareBracketToken: Token, elements: [Expression], closeSquareBracketToken: Token) {
    self.openSquareBracketToken = openSquareBracketToken
    self.elements = elements
    self.closeSquareBracketToken = closeSquareBracketToken
  }
}


/// A dictionary literal, such as "[1: 2, 3: 4]"
public struct DictionaryLiteral: SourceEntity {
  public var openSquareBracketToken: Token
  public var elements: [Entry]
  public var closeSquareBracketToken: Token

  public var sourceLocation: SourceLocation {
    return .spanning(openSquareBracketToken, to: closeSquareBracketToken)
  }

  public init(openSquareBracketToken: Token, elements: [Entry], closeSquareBracketToken: Token) {
    self.openSquareBracketToken = openSquareBracketToken
    self.elements = elements
    self.closeSquareBracketToken = closeSquareBracketToken
  }

  public struct Entry: Equatable {
    var key: Expression
    var value: Expression

    public init(key: Expression, value: Expression) {
      self.key = key
      self.value = value
    }
  }
}
