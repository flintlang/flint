//
//  EmitStatement.swift
//  AST
//
//  Created by Hails, Daniel R on 28/08/2018.
//
import Source
import Lexer

/// A emit statement.
public struct EmitStatement: ASTNode {
  public var emitToken: Token
  public var expression: Expression

  public init(emitToken: Token, expression: Expression) {
    self.emitToken = emitToken
    self.expression = expression
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return .spanning(emitToken, to: expression)
  }
  public var description: String {
    return "\(emitToken) \(expression)"
  }

}
