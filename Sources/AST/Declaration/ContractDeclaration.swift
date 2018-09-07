//
//  ContractDeclaration.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source
import Lexer

/// The declaration of a Flint contract.
public struct ContractDeclaration: ASTNode {
  public static var contractEnumPrefix = "flintStateEnum$"

  public var contractToken: Token
  public var identifier: Identifier
  public var states: [TypeState]
  public var members: [ContractMember]

  public var variableDeclarations: [VariableDeclaration] {
    return members.compactMap({ if case .variableDeclaration(let variableDeclaration) = $0 {
        return variableDeclaration
      }
      return nil
    })
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
    let cases: [EnumMember] = states.map{ typeState in
      return EnumMember(caseToken: caseToken, identifier: typeState.identifier, type: stateType, hiddenValue: nil, hiddenType: intType)
    }
    return EnumDeclaration(enumToken: enumToken, identifier: stateEnumIdentifier, type: intType, cases: cases)
  }

  public init(contractToken: Token, identifier: Identifier, states: [TypeState], members: [ContractMember]) {
    self.identifier = identifier
    self.members = members
    self.states = states
    self.contractToken = contractToken
  }

  // MARK: - ASTNode
  public var description: String {
    let stateText = states.map({ $0.description }).joined(separator: " ")
    let headText = "contract \(identifier) \(stateText)"
    let memberText = members.map({ $0.description }).joined(separator: "\n")
    return "\(headText) {\(memberText)}"
  }
  public var sourceLocation: SourceLocation {
    return .spanning(contractToken, to: identifier)
  }

}
