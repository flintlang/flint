//
//  BecomeStatement.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source
import Lexer

/// A become statement.
public struct BecomeStatement: ASTNode {
  public var becomeToken: Token
  public var expression: Expression

  public init(becomeToken: Token, expression: Expression) {
    self.becomeToken = becomeToken
    self.expression = expression
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return .spanning(becomeToken, to: expression)
  }
  public var description: String {
    return "\(becomeToken) \(expression)"
  }

}
