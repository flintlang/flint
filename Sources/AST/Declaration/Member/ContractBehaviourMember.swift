//
//  ContractBehaviourMember.swift
//  AST
//
//  Created by Hails, Daniel R on 28/08/2018.
//

import Source
import Lexer

/// A member in a contract behavior declaration.
///
/// - functionDeclaration: The declaration of a function.
/// - initializerDeclaration: The declaration of an initializer or fallback
public enum ContractBehaviorMember: ASTNode {
  case functionDeclaration(FunctionDeclaration)
  case specialDeclaration(SpecialDeclaration)

  // MARK: - ASTNode
  public var description: String {
    switch self {
    case .functionDeclaration(let functionDeclaration): return functionDeclaration.description
    case .specialDeclaration(let specialDeclaration): return specialDeclaration.description
    }
  }
  public var sourceLocation: SourceLocation {
    switch self {
    case .functionDeclaration(let functionDeclaration): return functionDeclaration.sourceLocation
    case .specialDeclaration(let specialDeclaration): return specialDeclaration.sourceLocation
    }
  }

}
