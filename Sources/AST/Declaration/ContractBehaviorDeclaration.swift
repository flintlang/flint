//
//  ContractBehaviorDeclaration.swift
//  flintc
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

/// A member in a contract behavior declaration.
///
/// - functionDeclaration: The declaration of a function.
/// - initializerDeclaration: The declaration of an initializer or fallback
public enum ContractBehaviorMember: Equatable, SourceEntity {
  case functionDeclaration(FunctionDeclaration)
  case specialDeclaration(SpecialDeclaration)

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

  public var sourceLocation: SourceLocation {
    return .spanning(contractIdentifier, to: closeBracketToken)
  }

  public init(contractIdentifier: Identifier, states: [TypeState], capabilityBinding: Identifier?, callerCapabilities: [CallerCapability], closeBracketToken: Token, members: [ContractBehaviorMember]) {
    self.contractIdentifier = contractIdentifier
    self.states = states
    self.capabilityBinding = capabilityBinding
    self.callerCapabilities = callerCapabilities
    self.closeBracketToken = closeBracketToken
    self.members = members
  }
}
