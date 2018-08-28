//
//  IfStatement.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source
import Lexer

/// An if statement.
public struct IfStatement: ASTNode {
  public var ifToken: Token
  public var condition: Expression

  /// The statements in the body of the if block.
  public var body: [Statement]

  /// the statements in the body of the else block.
  public var elseBody: [Statement]

  // Contextual information for the scope defined by the if body.
  public var ifBodyScopeContext: ScopeContext? = nil

  // Contextual information for the scope defined by the else body.
  public var elseBodyScopeContext: ScopeContext? = nil

  public var endsWithReturnStatement: Bool {
    return body.contains { statement in
      if case .returnStatement(_) = statement { return true }
      return false
    }
  }

  public init(ifToken: Token, condition: Expression, statements: [Statement], elseClauseStatements: [Statement]) {
    self.ifToken = ifToken
    self.condition = condition
    self.body = statements
    self.elseBody = elseClauseStatements
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return .spanning(ifToken, to: condition)
  }

  public var description: String {
    var elseText = ""
    if !elseBody.isEmpty {
      elseText = "\(elseBody.map({ $0.description }).joined(separator: "\n"))"
    }
    let bodyText = body.map({ $0.description }).joined(separator: "\n")
    return "\(ifToken) \(condition) {\(bodyText)} else {\(elseText)}"
  }
}

