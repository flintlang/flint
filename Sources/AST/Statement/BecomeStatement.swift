//
//  BecomeStatement.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

/// A become statement.
public struct BecomeStatement: SourceEntity {
  public var becomeToken: Token
  public var expression: Expression

  public var sourceLocation: SourceLocation {
    return .spanning(becomeToken, to: expression)
  }

  public init(becomeToken: Token, expression: Expression) {
    self.becomeToken = becomeToken
    self.expression = expression
  }
}
