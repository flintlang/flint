//
//  ReturnStatement.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source
import Lexer

/// A return statement.
public struct ReturnStatement: ASTNode {
  public var returnToken: Token
  public var expression: Expression?

  public init(returnToken: Token, expression: Expression?) {
    self.returnToken = returnToken
    self.expression = expression
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    if let expression = expression {
      return .spanning(returnToken, to: expression)
    }

    return returnToken.sourceLocation
  }

  public var description: String {
    if let expression = expression {
      return "\(returnToken) \(expression)"
    }
    return "\(returnToken)"
  }
}
