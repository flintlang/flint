//
//  TopLevelDeclaration.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

/// A Flint top-level declaration.
///
/// - contractDeclaration: The declaration of a contract.
/// - contractBehaviorDeclaration:  A Flint contract beheavior declaration, i.e. the functions of a contract for a given
///                                 caller capability group.
/// - structDeclaration:            The declaration of a struct.
public enum TopLevelDeclaration: Equatable {
  case contractDeclaration(ContractDeclaration)
  case contractBehaviorDeclaration(ContractBehaviorDeclaration)
  case structDeclaration(StructDeclaration)
  case enumDeclaration(EnumDeclaration)
}
