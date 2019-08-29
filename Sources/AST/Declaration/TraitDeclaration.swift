//
//  TraitDeclaration.swift
//  AST
//
//  Created by Harkness, Alexander L on 2018-09-05.
//
import Source
import Lexer

// The declaration of a trait.
public struct TraitDeclaration: ASTNode {
  public var traitKind: Token
  public var traitToken: Token
  public var identifier: Identifier
  // TODO: public var states: [TypeState]
  public var members: [TraitMember]
  public var moveModuleAddress: String?

  public init(
    traitKind: Token,
    traitToken: Token,
    identifier: Identifier,
    members: [TraitMember],
    moveModuleAddress: String? = nil
  ) {
    self.traitKind = traitKind
    self.traitToken = traitToken
    self.identifier = identifier
    self.members = members
    self.moveModuleAddress = moveModuleAddress
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return .spanning(traitToken, to: identifier)
  }

  public var description: String {
    let headText = "trait \(identifier)"
    let membersText = members.map({ $0.description }).joined(separator: "\n")
    return "\(headText) { \(membersText) }"
  }
}
