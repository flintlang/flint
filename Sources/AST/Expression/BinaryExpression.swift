//
//  BinaryExpression.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

/// A binary expression.
public struct BinaryExpression: ASTNode {
  public var lhs: Expression

  public var op: Token

  public var opToken: Token.Kind.Punctuation {
    guard case .punctuation(let token) = op.kind else { fatalError() }
    return token
  }

  public var rhs: Expression

  public var isExplicitPropertyAccess: Bool {
    if case .dot = opToken, case .self(_) = lhs {
      return true
    }
    return false
  }

  public init(lhs: Expression, op: Token, rhs: Expression) {
    self.lhs = lhs

    guard case .punctuation(_) = op.kind else {
      fatalError("Unexpected token kind \(op.kind) when trying to form a binary expression.")
    }

    self.op = op
    self.rhs = rhs
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return .spanning(lhs, to: rhs)
  }
  public var description: String {
    return "\(lhs) \(op) \(rhs)"
  }
}
