//
//  ContractMember.swift
//  AST
//
//  Created by Hails, Daniel J R on 28/08/2018.
//
import Source

/// A member in a contract declaration.
///
/// - variableDeclaration: The declaration of a variable.
/// - eventDeclaration: The declaration of an event.
/// - invariantDeclaration: The declaration of an invariant.
public enum ContractMember: ASTNode {
  case variableDeclaration(VariableDeclaration)
  case eventDeclaration(EventDeclaration)
  case invariantDeclaration(Expression)

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    switch self {
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.sourceLocation
    case .eventDeclaration(let eventDeclaration):
      return eventDeclaration.sourceLocation
    case .invariantDeclaration(let invariantDeclaration):
      return invariantDeclaration.sourceLocation
    }
  }

  public var description: String {
    switch self {
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.description
    case .eventDeclaration(let eventDeclaration):
      return eventDeclaration.description
    case .invariantDeclaration(let invariantDeclaration):
      return invariantDeclaration.description
    }
  }
}
