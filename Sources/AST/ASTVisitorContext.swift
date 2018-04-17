//
//  ASTVisitorContext.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 1/11/18.
//

public struct ContractBehaviorDeclarationContext {
  public var contractIdentifier: Identifier
  public var callerCapabilities: [CallerCapability]

  public init(contractIdentifier: Identifier, callerCapabilities: [CallerCapability]) {
    self.contractIdentifier = contractIdentifier
    self.callerCapabilities = callerCapabilities
  }
}

public struct StructDeclarationContext {
  public var structIdentifier: Identifier

  public init(structIdentifier: Identifier) {
    self.structIdentifier = structIdentifier
  }
}

public struct FunctionDeclarationContext {
  public var declaration: FunctionDeclaration

  public init(declaration: FunctionDeclaration) {
    self.declaration = declaration
  }

  public var isMutating: Bool {
    return declaration.isMutating
  }
}

public struct ScopeContext {
  public var localVariables = [VariableDeclaration]()

  public init(localVariables: [VariableDeclaration] = []) {
    self.localVariables = localVariables
  }

  public func containsVariableDeclaration(for name: String) -> Bool {
    return localVariables.contains { $0.identifier.name == name }
  }

  public func variableDeclaration(for name: String) -> VariableDeclaration? {
    return localVariables.first(where: { $0.identifier.name == name })
  }

  public func type(for variable: String) -> Type.RawType? {
    return localVariables.first(where: { $0.identifier.name == variable })?.type.rawType
  }
}
