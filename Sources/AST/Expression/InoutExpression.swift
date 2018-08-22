//
//  InoutExpression.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

/// An expression passed by reference, such as `&a`.
public struct InoutExpression: ASTNode {
  public var ampersandToken: Token
  public var expression: Expression

  public init(ampersandToken: Token, expression: Expression) {
    self.ampersandToken = ampersandToken
    self.expression = expression
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return .spanning(ampersandToken, to: expression)
  }

  public var description: String {
    return "\(ampersandToken)\(expression)"
  }
}
