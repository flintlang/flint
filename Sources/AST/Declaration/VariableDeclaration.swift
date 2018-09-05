//
//  VariableDeclaration.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source
import Lexer

/// The declaration of a variable or constant, either as a state property of a local variable.
public struct VariableDeclaration: ASTNode {
  public var modifiers: [Token]
  public var declarationToken: Token?
  public var identifier: Identifier
  public var type: Type
  public var assignedExpression: Expression?

  public init(modifiers: [Token], declarationToken: Token?, identifier: Identifier, type: Type, assignedExpression: Expression? = nil) {
    self.modifiers = modifiers
    self.declarationToken = declarationToken
    self.identifier = identifier
    self.type = type
    self.assignedExpression = assignedExpression
  }

  public var isConstant: Bool {
    return declarationToken?.kind == .let
  }

  public var isVariable: Bool {
    return declarationToken?.kind == .var
  }

  // MARK: - Modifier Checks
  public var isMutating: Bool {
    return hasModifier(kind: .mutating)
  }

  public var isVisible: Bool {
    return hasModifier(kind: .visible)
  }

  public var isPublic: Bool {
    return hasModifier(kind: .public)
  }

  private func hasModifier(kind: Token.Kind) -> Bool {
    return modifiers.contains { $0.kind == kind }
  }
  // MARK: - ASTNode
  public var description: String {
    return "\(declarationToken?.description ?? "") \(identifier): \(type)"
  }
  public var sourceLocation: SourceLocation {
    if let declarationToken = declarationToken {
      return .spanning(declarationToken, to: type)
    }
    return .spanning(identifier, to: type)
  }
}
