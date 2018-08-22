//
//  Statement.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

/// A statement.
public indirect enum Statement: ASTNode {

  case expression(Expression)
  case returnStatement(ReturnStatement)
  case becomeStatement(BecomeStatement)
  case ifStatement(IfStatement)
  case forStatement(ForStatement)

  public var isEnding: Bool {
    switch self {
    case .returnStatement(_), .becomeStatement(_): return true
    default: return false
    }
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    switch self {
    case .expression(let expression): return expression.sourceLocation
    case .returnStatement(let returnStatement): return returnStatement.sourceLocation
    case .becomeStatement(let becomeStatement): return becomeStatement.sourceLocation
    case .ifStatement(let ifStatement): return ifStatement.sourceLocation
    case .forStatement(let forStatement): return forStatement.sourceLocation
    }
  }
  public var description: String {
    switch self {
    case .expression(let expression): return expression.description
    case .returnStatement(let returnStatement): return returnStatement.description
    case .becomeStatement(let becomeStatement): return becomeStatement.description
    case .ifStatement(let ifStatement): return ifStatement.description
    case .forStatement(let forStatement): return forStatement.description
    }
  }
}
