//
//  ASTVisitorContext.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 1/11/18.
//

public struct ContractBehaviorDeclarationContext {
  public var contractIdentifier: Identifier
  public var contractProperties: [VariableDeclaration]
  public var callerCapabilities: [CallerCapability]

  public init(contractIdentifier: Identifier, contractProperties: [VariableDeclaration], callerCapabilities: [CallerCapability]) {
    self.contractIdentifier = contractIdentifier
    self.contractProperties = contractProperties
    self.callerCapabilities = callerCapabilities
  }

  public func isPropertyDeclared(_ name: String) -> Bool {
    return contractProperties.contains { $0.identifier.name == name }
  }
}


public struct FunctionDeclarationContext {
  public var declaration: FunctionDeclaration
  public var contractContext: ContractBehaviorDeclarationContext

  public init(declaration: FunctionDeclaration, contractContext: ContractBehaviorDeclarationContext) {
    self.declaration = declaration
    self.contractContext = contractContext
  }

  public var isMutating: Bool {
    return declaration.isMutating
  }
}
