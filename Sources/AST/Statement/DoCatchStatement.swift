//
//  DoCatchStatement.swift
//  AST
//
//  Created by Ethan on 05/11/2018.
//
import Source
import Lexer

/// A do catch block.
public struct DoCatchStatement: ASTNode {
  public var doBody: [Statement]
  public var catchBody: [Statement]
  public var error: Expression
  var startToken: Token
  var endToken: Token

  public init(doBody: [Statement], catchBody: [Statement], error: Expression, startToken: Token, endToken: Token) {
    self.doBody = doBody
    self.catchBody = catchBody
    self.error = error
    self.startToken = startToken
    self.endToken = endToken
  }

  // Does the do-body contain a call on this level of nesting, may be set while visiting a statement in doBody
  public var containsExternalCall = false

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return SourceLocation.spanning(startToken, to: endToken)
  }

  public var description: String {
    let doBodyText = doBody.map({ $0.description }).joined(separator: "\n")
    let catchBodyText = catchBody.map({ $0.description }).joined(separator: "\n")
    return "do {\(doBodyText)} catch {\(catchBodyText)}"
  }
}
