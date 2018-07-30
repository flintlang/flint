//
//  ASTVisitorContext.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 1/11/18.
//

/// Contextual information used when visiting the state properties declared in a contract declaration.
public struct ContractStateDeclarationContext {
  public var contractIdentifier: Identifier
}

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

/// Contextual information used when visiting declarations in a enum, such as the name of the enum the cases
/// are declared for.
public struct EnumDeclarationContext {
  public var enumIdentifier: Identifier
  
  public init(enumIdentifier: Identifier) {
    self.enumIdentifier = enumIdentifier
  }
}

/// Contextual information used when visiting statements in a function, such as if the function is mutating or not.
public struct FunctionDeclarationContext {
  public var declaration: FunctionDeclaration

  public init(declaration: FunctionDeclaration) {
    self.declaration = declaration
  }

  public var isMutating: Bool {
    return declaration.isMutating
  }
}

/// Contextual information used when visiting statements in an initializer.
public struct InitializerDeclarationContext {
  public var declaration: InitializerDeclaration

  public init(declaration: InitializerDeclaration) {
    self.declaration = declaration
  }
}

/// Contextual information used when visiting a scope, such as the local variables which are accessible in that
/// scope.
public struct ScopeContext: Equatable {
  public var parameters = [Parameter]()
  public var localVariables = [VariableDeclaration]()

  public init(parameters: [Parameter] = [], localVariables: [VariableDeclaration] = []) {
    self.parameters = parameters
    self.localVariables = localVariables
  }

  public func containsParameterDeclaration(for name: String) -> Bool {
    return parameters.contains { $0.identifier.name == name }
  }

  public func containsVariableDeclaration(for name: String) -> Bool {
    return localVariables.contains { $0.identifier.name == name }
  }

  public func containsDeclaration(for name: String) -> Bool {
    return containsParameterDeclaration(for: name) || containsVariableDeclaration(for: name)
  }

  public func declaration(for name: String) -> VariableDeclaration? {
    let all = localVariables + parameters.map { $0.asVariableDeclaration }
    return all.first(where: { $0.identifier.name == name })
  }

  public func type(for variable: String) -> Type.RawType? {
    let all = localVariables + parameters.map { $0.asVariableDeclaration }
    return all.first(where: { $0.identifier.name == variable })?.type.rawType
  }

  /// Whether the given parameter is implicit.
  public func isParameterImplicit(_ parameterName: String) -> Bool {
    guard let parameter = parameters.first(where: { $0.identifier.name == parameterName }) else {
      fatalError("Parameter \(parameterName) does not exist.")
    }
    return parameter.isImplicit
  }

  /// Returns the parameter name for the enclosing identifier of the given expression.
  ///
  /// For example, when given the expression "a.foo.x", the function will return "a" if "a" is a parameter to the
  /// function.
  public func enclosingParameter(expression: Expression, enclosingTypeName: String) -> String? {
    guard expression.enclosingType != enclosingTypeName,
      let enclosingIdentifier = expression.enclosingIdentifier,
      containsParameterDeclaration(for: enclosingIdentifier.name) else {
      return nil
    }

    return enclosingIdentifier.name
  }
}
