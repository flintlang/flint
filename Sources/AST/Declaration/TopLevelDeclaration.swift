//
//  TopLevelDeclaration.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source

/// A Flint top-level declaration.
///
/// - contractDeclaration: The declaration of a contract.
/// - contractBehaviorDeclaration:  A Flint contract beheavior declaration, i.e. the functions of a contract for a given
///                                 caller capability group.
/// - structDeclaration:            The declaration of a struct.
public enum TopLevelDeclaration: ASTNode {
  case contractDeclaration(ContractDeclaration)
  case contractBehaviorDeclaration(ContractBehaviorDeclaration)
  case structDeclaration(StructDeclaration)
  case enumDeclaration(EnumDeclaration)
  case traitDeclaration(TraitDeclaration)

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    switch self {
      case .contractDeclaration(let contractDeclaration):
        return contractDeclaration.sourceLocation
      case .contractBehaviorDeclaration(let behaviourDeclaration):
        return behaviourDeclaration.sourceLocation
      case .structDeclaration(let structDeclaration):
        return structDeclaration.sourceLocation
      case .enumDeclaration(let enumDeclaration):
        return enumDeclaration.sourceLocation
      case .traitDeclaration(let traitDeclaration):
        return traitDeclaration.sourceLocation
    }
  }

  public var description: String {
    switch self {
    case .contractDeclaration(let contractDeclaration):
      return contractDeclaration.description
    case .contractBehaviorDeclaration(let behaviourDeclaration):
      return behaviourDeclaration.description
    case .structDeclaration(let structDeclaration):
      return structDeclaration.description
    case .enumDeclaration(let enumDeclaration):
      return enumDeclaration.description
    case .traitDeclaration(let traitDeclaration):
      return traitDeclaration.description
    }
  }
}
