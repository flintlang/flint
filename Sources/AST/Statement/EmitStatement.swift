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
  public var functionCall: FunctionCall

  public init(emitToken: Token, functionCall: FunctionCall) {
    self.emitToken = emitToken
    self.functionCall = functionCall
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return .spanning(emitToken, to: functionCall)
  }
  public var description: String {
    return "\(emitToken) \(functionCall)"
  }

}
