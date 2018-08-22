//
//  ForStatement.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source
import Lexer

/// A for statement.
public struct ForStatement: ASTNode {
  public var forToken: Token
  public var variable: VariableDeclaration
  public var iterable: Expression

  /// The statements in the body of the for block.
  public var body: [Statement]

  // Contextual information for the scope defined by the for body.
  public var forBodyScopeContext: ScopeContext? = nil

  public var endsWithReturnStatement: Bool {
    return body.contains { statement in
      if case .returnStatement(_) = statement { return true }
      return false
    }
  }

  public init(forToken: Token, variable: VariableDeclaration, iterable: Expression, statements: [Statement]) {
    self.forToken = forToken
    self.variable = variable
    self.iterable = iterable
    self.body = statements
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return .spanning(forToken, to: iterable)
  }

  public var description: String {
    let statementText = body.map({ $0.description }).joined(separator: "\n")
    return "\(forToken) \(variable) in \(iterable) {\(statementText)}"
  }
}
