//
//  IfStatement.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

/// An if statement.
public struct IfStatement: SourceEntity {
  public var ifToken: Token
  public var condition: Expression

  /// The statements in the body of the if block.
  public var body: [Statement]

  /// the statements in the body of the else block.
  public var elseBody: [Statement]

  public var sourceLocation: SourceLocation {
    return .spanning(ifToken, to: condition)
  }

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
}

