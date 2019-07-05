//
//  StructMember.swift
//  AST
//
//  Created by Hails, Daniel J R on 28/08/2018.
//
import Source
import Lexer

/// A member in a struct declaration.
///
/// - variableDeclaration: The declaration of a variable.
/// - functionDeclaration: The declaration of a function.
/// - invariantDeclaration: The declaration of an invariant.
public enum StructMember: ASTNode {
  case variableDeclaration(VariableDeclaration)
  case functionDeclaration(FunctionDeclaration)
  case specialDeclaration(SpecialDeclaration)
  case invariantDeclaration(Expression)

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    switch self {
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.sourceLocation
    case .functionDeclaration(let functionDeclaration):
      return functionDeclaration.sourceLocation
    case .specialDeclaration(let specialDeclaration):
      return specialDeclaration.sourceLocation
    case .invariantDeclaration(let expression):
      return expression.sourceLocation
    }
  }

  public var description: String {
    switch self {
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.description
    case .functionDeclaration(let functionDeclaration):
      return functionDeclaration.description
    case .specialDeclaration(let specialDeclaration):
      return specialDeclaration.description
    case .invariantDeclaration(let expression):
      return expression.description
    }
  }
}
