//
//  RangeExpression.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

public struct RangeExpression: SourceEntity {
  public var openSquareBracketToken: Token
  public var closeSquareBracketToken: Token

  public var initial: Expression
  public var bound: Expression
  public var op: Token

  public var sourceLocation: SourceLocation {
    return .spanning(openSquareBracketToken, to: closeSquareBracketToken)
  }

  public var isClosed: Bool {
    return op.kind == .punctuation(.closedRange)
  }

  public init(startToken: Token, endToken: Token, initial: Expression, bound: Expression, op: Token){
    self.openSquareBracketToken = startToken
    self.closeSquareBracketToken = endToken
    self.initial = initial
    self.bound = bound
    self.op = op
  }
}
