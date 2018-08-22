//
//  ContractBehaviorDeclaration.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
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

/// A Flint contract behavior declaration, i.e. the functions of a contract for a given caller capability group.
public struct ContractBehaviorDeclaration: SourceEntity {
  public var contractIdentifier: Identifier
  public var capabilityBinding: Identifier?
  public var callerCapabilities: [CallerCapability]

  public var states: [TypeState]

  public var members: [ContractBehaviorMember]
  public var closeBracketToken: Token

  public init(contractIdentifier: Identifier, states: [TypeState], capabilityBinding: Identifier?, callerCapabilities: [CallerCapability], closeBracketToken: Token, members: [ContractBehaviorMember]) {
    self.contractIdentifier = contractIdentifier
    self.states = states
    self.capabilityBinding = capabilityBinding
    self.callerCapabilities = callerCapabilities
    self.closeBracketToken = closeBracketToken
    self.members = members
  }

  // MARK: - ASTNode
  public var description: String {
    let statesText = states.map({$0.description}).joined(separator: ", ")
    let callerText = callerCapabilities.map({ $0.description }).joined(separator: ", ")
    let headText = "\(contractIdentifier) @\(statesText):: \(callerText)"
    let membersText = members.map({ $0.description }).joined(separator: "\n")
    return "\(headText) {\(membersText)}"
  }
  public var sourceLocation: SourceLocation {
    return .spanning(contractIdentifier, to: closeBracketToken)
  }
}
