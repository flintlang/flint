//
//  ContractBehaviorDeclaration.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

import Source
import Lexer

/// A Flint contract behavior declaration, i.e. the functions of a contract for given protections.
public struct ContractBehaviorDeclaration: SourceEntity {
  public var contractIdentifier: Identifier
  public var states: [TypeState]
  public var callerBinding: Identifier?
  public var callerProtections: [CallerProtection]
  public var closeBracketToken: Token
  public var members: [ContractBehaviorMember]

  public init(contractIdentifier: Identifier,
              states: [TypeState],
              callerBinding: Identifier?,
              callerProtections: [CallerProtection],
              closeBracketToken: Token,
              members: [ContractBehaviorMember]) {
    self.contractIdentifier = contractIdentifier
    self.states = states
    self.callerBinding = callerBinding
    self.callerProtections = callerProtections
    self.closeBracketToken = closeBracketToken
    self.members = members
  }

  // MARK: - ASTNode
  public var description: String {
    let statesText = states.map({$0.description}).joined(separator: ", ")
    let callerText = callerProtections.map({ $0.description }).joined(separator: ", ")
    let headText = "\(contractIdentifier) @\(statesText) :: \(callerText)"
    let membersText = members.map({ $0.description }).joined(separator: "\n")
    return "\(headText) {\(membersText)}"
  }
  public var sourceLocation: SourceLocation {
    return .spanning(contractIdentifier, to: closeBracketToken)
  }
}
