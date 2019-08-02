//
//  EventDeclaration.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source
import Lexer

/// The declaration of an event.
public struct EventDeclaration: ASTNode {
  public var eventToken: Token
  public var identifier: Identifier
  public var variableDeclarations: [VariableDeclaration]

  public init(eventToken: Token, identifier: Identifier, parameters: [Parameter]) {
    self.eventToken = eventToken
    self.identifier = identifier
    self.variableDeclarations = parameters.map { $0.asVariableDeclaration }
  }

  // MARK: - ASTNode
  public var description: String {
    let variableText = variableDeclarations.map({ $0.description }).joined(separator: "\n")
    return "\(eventToken) \(identifier) {\(variableText)}"
  }
  public var sourceLocation: SourceLocation {
    return .spanning(eventToken, to: identifier)
  }
}
