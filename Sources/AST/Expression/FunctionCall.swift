//
//  FunctionCall.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source
import Lexer

/// A call to a function.
public struct FunctionCall: ASTNode {
  public var identifier: Identifier
  public var arguments: [FunctionArgument]
  public var closeBracketToken: Token
  public var isAttempted: Bool

  public var mangledIdentifier: String? = nil

  public init(identifier: Identifier, arguments: [FunctionArgument], closeBracketToken: Token, isAttempted: Bool) {
    self.identifier = identifier
    self.arguments = arguments
    self.closeBracketToken = closeBracketToken
    self.isAttempted = isAttempted
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return .spanning(identifier, to: closeBracketToken)
  }

  public var description: String {
    let argumentText = arguments.map({ $0.description }).joined(separator: ", ")
    return "\(identifier)(\(argumentText))"
  }
}
