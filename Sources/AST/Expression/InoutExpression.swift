//
//  InoutExpression.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

/// An expression passed by reference, such as `&a`.
public struct InoutExpression: SourceEntity {
  public var ampersandToken: Token
  public var expression: Expression

  public var sourceLocation: SourceLocation {
    return .spanning(ampersandToken, to: expression)
  }

  public init(ampersandToken: Token, expression: Expression) {
    self.ampersandToken = ampersandToken
    self.expression = expression
  }
}
