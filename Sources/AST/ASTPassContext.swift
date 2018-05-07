//
//  PassContext.swift
//  AST
//
//  Created by Franklin Schrans on 1/16/18.
//

/// Information collected when performing a pass over an AST.
///
/// Entries in a context are accessible as properties, or through a subscript, which takes a `PassContexEntry` value.
public struct ASTPassContext {
  /// Backing storage for the context.
  var storage = [AnyHashable: Any]()

  public init() {}

  public subscript<Entry: PassContextEntry>(_ contextEntry: Entry.Type) -> Entry.Value? {
    get { return storage[contextEntry.hashValue] as? Entry.Value }
    set { storage[contextEntry.hashValue] = newValue }
  }

  /// Returns an `ASTPassContext` modified with the updates specified in `updates`.
  ///
  /// Example:
  /// ```swift
  /// let newContext = context.withUpdates {
  ///    context.asLValue = true
  /// }
  /// // newContext.asLValue == true
  /// ```
  ///
  /// - Parameter updates: The modifications which should be applied to the new `ASTPassContext`.
  /// - Returns: The `ASTPassContext` applied with the `updates`.
  public func withUpdates(updates: (inout ASTPassContext) -> ()) -> ASTPassContext {
    var copy = self
    updates(&copy)
    return copy
  }
}

extension ASTPassContext {

  // Convenience properties to access entries in an `ASTPassContext`.

  /// Information collected about a source program, such as the contracts and structs declared.
  public var environment: Environment? {
    get { return self[EnvironmentContextEntry.self] }
    set { self[EnvironmentContextEntry.self] = newValue }
  }

  /// Whether the node currently being visited (in this case, a variable), is being interpreted as an l-value (i.e.,
  /// on the left-hand side of an assignment).
  public var asLValue: Bool? {
    get { return self[AsLValueContextEntry.self] }
    set { self[AsLValueContextEntry.self] = newValue }
  }

  /// Contextual information used when visiting the state properties declared in a contract declaration.
  public var contractStateDeclarationContext: ContractStateDeclarationContext? {
    get { return self[ContractStateDeclarationContextEntry.self] }
    set { self[ContractStateDeclarationContextEntry.self] = newValue }
  }

  /// Contextual information used when visiting functions in a contract behavior declaration, such as the name of the
  /// contract the functions are declared for, and the caller capability associated with them.
  public var contractBehaviorDeclarationContext: ContractBehaviorDeclarationContext? {
    get { return self[ContractBehaviorDeclarationContextEntry.self] }
    set { self[ContractBehaviorDeclarationContextEntry.self] = newValue }
  }

  /// Contextual information used when visiting declarations in a struct, such as the name of the struct the functions
  /// are declared for.
  public var structDeclarationContext: StructDeclarationContext? {
    get { return self[StructDeclarationContextEntry.self] }
    set { self[StructDeclarationContextEntry.self] = newValue }
  }

  /// Contextual information used when visiting statements in a function, such as if the function is mutating or note.
  public var functionDeclarationContext: FunctionDeclarationContext? {
    get { return self[FunctionDeclarationContextEntry.self] }
    set { self[FunctionDeclarationContextEntry.self] = newValue }
  }

  /// Contextual information used when visiting statements in an initializer.
  public var initializerDeclarationContext: InitializerDeclarationContext? {
    get { return self[InitializerDeclarationContextEntry.self] }
    set { self[InitializerDeclarationContextEntry.self] = newValue }
  }

  /// Contextual information used when visiting a scope, such as the local variables which are accessible in that
  /// scope.
  public var scopeContext: ScopeContext? {
    get { return self[ScopeContextContextEntry.self] }
    set { self[ScopeContextContextEntry.self] = newValue }
  }

  /// When visiting arguments in a function call, this property is set to `true`.
  public var isFunctionCall: Bool? {
    get { return self[IsFunctionCallContextEntry.self] }
    set { self[IsFunctionCallContextEntry.self] = newValue }
  }

  /// The identifier of the enclosing type (a contract or a struct).
  public var enclosingTypeIdentifier: Identifier? {
    return contractBehaviorDeclarationContext?.contractIdentifier ??
      structDeclarationContext?.structIdentifier ??
      contractStateDeclarationContext?.contractIdentifier
  }

  /// Whether we are visiting a node in a function declaration or initializer.
  public var inFunctionOrInitializer: Bool {
    return functionDeclarationContext != nil || functionDeclarationContext != nil
  }
}

/// A entry used to index in an `ASTPassContext`.
public protocol PassContextEntry {
  associatedtype Value
}

extension PassContextEntry {
  static var hashValue: Int {
    return ObjectIdentifier(Self.self).hashValue
  }
}

private struct EnvironmentContextEntry: PassContextEntry {
  typealias Value = Environment
}

private struct AsLValueContextEntry: PassContextEntry {
  typealias Value = Bool
}

private struct ContractStateDeclarationContextEntry: PassContextEntry {
  typealias Value = ContractStateDeclarationContext
}

private struct ContractBehaviorDeclarationContextEntry: PassContextEntry {
  typealias Value = ContractBehaviorDeclarationContext
}

private struct StructDeclarationContextEntry: PassContextEntry {
  typealias Value = StructDeclarationContext
}

private struct FunctionDeclarationContextEntry: PassContextEntry {
  typealias Value = FunctionDeclarationContext
}

private struct InitializerDeclarationContextEntry: PassContextEntry {
  typealias Value = InitializerDeclarationContext
}

private struct ScopeContextContextEntry: PassContextEntry {
  typealias Value = ScopeContext
}

private struct IsFunctionCallContextEntry: PassContextEntry {
  typealias Value = Bool
}
