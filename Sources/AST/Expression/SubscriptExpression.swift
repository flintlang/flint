//
//  SubscriptExpression.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

/// A subscript expression such as `a[2]`.
public struct SubscriptExpression: ASTNode {
  public var baseExpression: Expression
  public var indexExpression: Expression
  public var closeSquareBracketToken: Token

  public init(baseExpression: Expression, indexExpression: Expression, closeSquareBracketToken: Token) {
    self.baseExpression = baseExpression
    self.indexExpression = indexExpression
    self.closeSquareBracketToken = closeSquareBracketToken
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return .spanning(baseExpression, to: closeSquareBracketToken)
  }

  public var description: String {
    return "\(baseExpression)[\(indexExpression)]"
  }
}
