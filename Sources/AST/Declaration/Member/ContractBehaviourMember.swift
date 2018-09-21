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
  case functionSignatureDeclaration(FunctionSignatureDeclaration)
  case specialSignatureDeclaration(SpecialSignatureDeclaration)

  // MARK: - ASTNode
  public var description: String {
    switch self {
    case .functionDeclaration(let decl): return decl.description
    case .specialDeclaration(let decl): return decl.description
    case .functionSignatureDeclaration(let decl): return decl.description
    case .specialSignatureDeclaration(let decl): return decl.description
    }
  }
  public var sourceLocation: SourceLocation {
    switch self {
    case .functionDeclaration(let decl): return decl.sourceLocation
    case .specialDeclaration(let decl): return decl.sourceLocation
    case .functionSignatureDeclaration(let decl): return decl.sourceLocation
    case .specialSignatureDeclaration(let decl): return decl.sourceLocation
    }
  }

}
