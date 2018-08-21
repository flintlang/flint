//
//  ReturnStatement.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

/// A return statement.
public struct ReturnStatement: SourceEntity {
  public var returnToken: Token
  public var expression: Expression?

  public var sourceLocation: SourceLocation {
    if let expression = expression {
      return .spanning(returnToken, to: expression)
    }

    return returnToken.sourceLocation
  }

  public init(returnToken: Token, expression: Expression?) {
    self.returnToken = returnToken
    self.expression = expression
  }
}
