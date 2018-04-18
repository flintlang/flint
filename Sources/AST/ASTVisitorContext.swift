//
//  ASTVisitorContext.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 1/11/18.
//

/// Contextual information used when visiting functions in a contract behavior declaration, such as the name of the
/// contract the functions are declared for, and the caller capability associated with them.
public struct ContractBehaviorDeclarationContext {
  public var contractIdentifier: Identifier
  public var callerCapabilities: [CallerCapability]

  public init(contractIdentifier: Identifier, callerCapabilities: [CallerCapability]) {
    self.contractIdentifier = contractIdentifier
    self.callerCapabilities = callerCapabilities
  }
}

/// Contextual information used when visiting declarations in a struct, such as the name of the struct the functions
/// are declared for.
public struct StructDeclarationContext {
  public var structIdentifier: Identifier

  public init(structIdentifier: Identifier) {
    self.structIdentifier = structIdentifier
  }
}

/// Contextual information used when visiting statements in a function, such as if it is mutating or note.
public struct FunctionDeclarationContext {
  public var declaration: FunctionDeclaration

  public init(declaration: FunctionDeclaration) {
    self.declaration = declaration
  }

  public var isMutating: Bool {
    return declaration.isMutating
  }
}

/// Contextual information used when visiting a scope, such as the local variables which are accessible in that
/// scope.
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
