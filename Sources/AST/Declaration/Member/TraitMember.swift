//
//  TraitMember.swift
//  AST
//
//  Created by Harkness, Alexander L on 2018-09-05.
//
import Source

/// A member in a trait declaration.
///
/// - functionDeclaration - The declaration of a function
/// - functionSignatureDeclaration - The declaration of a function signature
/// - eventDeclaration - The declaration of an event
public enum TraitMember: ASTNode {
  case functionDeclaration(FunctionDeclaration)
  case specialDeclaration(SpecialDeclaration)
  case functionSignatureDeclaration(FunctionSignatureDeclaration)
  case specialSignatureDeclaration(SpecialSignatureDeclaration)
  case contractBehaviourDeclaration(ContractBehaviorDeclaration)
  case eventDeclaration(EventDeclaration)

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    switch self {
    case .functionDeclaration(let functionDeclaration):
      return functionDeclaration.sourceLocation
    case .functionSignatureDeclaration(let functionSignatureDeclaration):
      return functionSignatureDeclaration.sourceLocation
    case .specialDeclaration(let specialDeclaration):
      return specialDeclaration.sourceLocation
    case .specialSignatureDeclaration(let specialSignatureDeclaration):
      return specialSignatureDeclaration.sourceLocation
    case .contractBehaviourDeclaration(let contractBehaviourDeclaration):
      return contractBehaviourDeclaration.sourceLocation
    case .eventDeclaration(let eventDeclaration):
      return eventDeclaration.sourceLocation
    }
  }

  public var description: String {
    switch self {
    case .functionDeclaration(let functionDeclaration):
      return functionDeclaration.description
    case .specialDeclaration(let specialDeclaration):
      return specialDeclaration.description
    case .functionSignatureDeclaration(let functionSignatureDeclaration):
      return functionSignatureDeclaration.description
    case .specialSignatureDeclaration(let specialSignatureDeclaration):
      return specialSignatureDeclaration.description
    case .contractBehaviourDeclaration(let contractBehaviourDeclaration):
      return contractBehaviourDeclaration.description
    case .eventDeclaration(let eventDeclaration):
      return eventDeclaration.description
    }
  }
}
