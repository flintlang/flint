//
//  SubscriptExpression.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

/// A subscript expression such as `a[2]`.
public struct SubscriptExpression: SourceEntity {
  public var baseExpression: Expression
  public var indexExpression: Expression
  public var closeSquareBracketToken: Token

  public var sourceLocation: SourceLocation {
    return .spanning(baseExpression, to: closeSquareBracketToken)
  }

  public init(baseExpression: Expression, indexExpression: Expression, closeSquareBracketToken: Token) {
    self.baseExpression = baseExpression
    self.indexExpression = indexExpression
    self.closeSquareBracketToken = closeSquareBracketToken
  }
}
