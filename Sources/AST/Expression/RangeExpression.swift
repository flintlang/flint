//
//  RangeExpression.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source
import Lexer

public struct RangeExpression: ASTNode {
  public var openToken: Token
  public var closeToken: Token

  public var initial: Expression
  public var bound: Expression
  public var op: Token

  public var isClosed: Bool {
    return op.kind == .punctuation(.closedRange)
  }

  public init(openToken: Token, endToken: Token, initial: Expression, bound: Expression, op: Token){
    self.openToken = openToken
    self.closeToken = endToken
    self.initial = initial
    self.bound = bound
    self.op = op
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return .spanning(openToken, to: closeToken)
  }

  public var description: String {
    return "\(openToken)\(initial)\(op)\(bound)\(closeToken)"
  }
}
