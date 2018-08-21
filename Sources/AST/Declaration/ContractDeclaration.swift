//
//  ContractDeclaration.swift
//  flintc
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

/// The declaration of a Flint contract.
public struct ContractDeclaration: SourceEntity {
  public static var contractEnumPrefix = "flintStateEnum$"

  public var contractToken: Token
  public var identifier: Identifier
  public var states: [TypeState]
  public var variableDeclarations: [VariableDeclaration]

  public var sourceLocation: SourceLocation {
    return .spanning(contractToken, to: identifier)
  }

  public var isStateful: Bool {
    return !states.isEmpty
  }

  public var stateEnumIdentifier: Identifier {
    return Identifier(identifierToken: Token(kind: .identifier(ContractDeclaration.contractEnumPrefix+identifier.name), sourceLocation: sourceLocation))
  }

  private var stateType: Type {
    return Type(identifier: stateEnumIdentifier)
  }

  public var stateEnum: EnumDeclaration {
    let enumToken = Token(kind: .enum, sourceLocation: sourceLocation)
    let caseToken = Token(kind: .case, sourceLocation: sourceLocation)
    let intType = Type(inferredType: .basicType(.int), identifier: stateEnumIdentifier)
    let cases: [EnumCase] = states.map{ typeState in
      return EnumCase(caseToken: caseToken, identifier: typeState.identifier, type: stateType, hiddenValue: nil, hiddenType: intType)
    }
    return EnumDeclaration(enumToken: enumToken, identifier: stateEnumIdentifier, type: intType, cases: cases)
  }

  public init(contractToken: Token, identifier: Identifier, states: [TypeState], variableDeclarations: [VariableDeclaration]) {
    self.identifier = identifier
    self.variableDeclarations = variableDeclarations
    self.states = states
    self.contractToken = contractToken
  }
}
