//
//  BracketedExpression.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

/// A bracketed expression.
public struct BracketedExpression: ASTNode {
  public var expression: Expression

  public var openBracketToken: Token
  public var closeBracketToken: Token

  public init(expression: Expression, openBracketToken: Token, closeBracketToken: Token) {
    guard case .punctuation(.openBracket) = openBracketToken.kind else {
      fatalError("Unexpected token kind \(openBracketToken.kind) when trying to form a bracketed expression.")
    }

    guard case .punctuation(.closeBracket) = closeBracketToken.kind else {
      fatalError("Unexpected token kind \(closeBracketToken.kind) when trying to form a bracketed expression.")
    }

    self.expression = expression
    self.openBracketToken = openBracketToken
    self.closeBracketToken = closeBracketToken
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return .spanning(openBracketToken, to: closeBracketToken)
  }

  public var description: String {
    return "\(openBracketToken)\(expression)\(closeBracketToken)"
  }
}
