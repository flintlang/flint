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
  public func withUpdates(updates: (inout ASTPassContext) -> Void) -> ASTPassContext {
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

  /// Whether the node currently being visited is inside a subscript i.e. 'a' in 'foo[a]'
  public var isInSubscript: Bool {
    get { return self[IsInSubscriptEntry.self] ?? false }
    set { self[IsInSubscriptEntry.self] = newValue }
  }

  /// Whether the node currently being visited is being the enclosing variable i.e. 'a' in 'a.foo'
  public var isEnclosing: Bool {
    get { return self[IsEnclosingEntry.self] ?? false }
    set { self[IsEnclosingEntry.self] = newValue }
  }

  /// Whether the node currently being visited is within a become statement i.e. 'a' in 'become a'
  public var isInBecome: Bool {
    get { return self[IsInBecomeEntry.self] ?? false }
    set { self[IsInBecomeEntry.self] = newValue }
  }

  /// Whether the node currently being visited is within a emit statement i.e. 'a' in 'emit a'
  public var isInEmit: Bool {
    get { return self[IsInEmitEntry.self] ?? false }
    set { self[IsInEmitEntry.self] = newValue }
  }

  /// Contextual information used when visiting the state properties declared in a contract declaration.
  public var contractStateDeclarationContext: ContractStateDeclarationContext? {
    get { return self[ContractStateDeclarationContextEntry.self] }
    set { self[ContractStateDeclarationContextEntry.self] = newValue }
  }

  /// Contextual information used when visiting functions in a contract behavior declaration, such as the name of the
  /// contract the functions are declared for, and the caller protections associated with them.
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

  /// Contextual information used when visiting declarations in a enum, such as the name of the enum the cases
  /// are declared for.
  public var enumDeclarationContext: EnumDeclarationContext? {
    get { return self[EnumDeclarationContextEntry.self] }
    set { self[EnumDeclarationContextEntry.self] = newValue }
  }

  /// Contextual information used when visiting declarations in a trait declaration, such as the
  /// name of the trait the members belong to.
  public var traitDeclarationContext: TraitDeclarationContext? {
    get { return self[TraitDeclarationContextEntry.self] }
    set { self[TraitDeclarationContextEntry.self] = newValue }
  }

  /// Contextual information used when visiting declarations in an event, such as the name of the event
  public var eventDeclarationContext: EventDeclarationContext? {
    get { return self[EventDeclarationContextEntry.self] }
    set { self[EventDeclarationContextEntry.self] = newValue }
  }

  /// Contextual information used when visiting statements in a function, such as if the function is mutating or note.
  public var functionDeclarationContext: FunctionDeclarationContext? {
    get { return self[FunctionDeclarationContextEntry.self] }
    set { self[FunctionDeclarationContextEntry.self] = newValue }
  }

  /// Contextual information used when visiting statements in an initializer.
  public var specialDeclarationContext: SpecialDeclarationContext? {
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
  public var isFunctionCall: Bool {
    get { return self[IsFunctionCallContextEntry.self] ?? false }
    set { self[IsFunctionCallContextEntry.self] = newValue }
  }

  /// When visiting an external call, this property is set to `true`.
  public var isExternalCall: Bool {
    get { return self[IsExternalCallContextEntry.self] ?? false }
    set { self[IsExternalCallContextEntry.self] = newValue }
  }

  /// When visiting argument labels in a function call, this property is set to `true`.
  public var isFunctionCallArgumentLabel: Bool {
    get { return self[IsFunctionCallArgumentLabel.self] ?? false }
    set { self[IsFunctionCallArgumentLabel.self] = newValue }
  }

  /// When visiting an external configuration parameter, this property is set to `true`.
  /// External configuration params are hyper-parameters to the call, like the gas, the
  /// wei used for the external call or reentrancy.
  public var isExternalConfigurationParam: Bool {
    get { return self[IsExternalConfigurationParam.self] ?? false }
    set { self[IsExternalConfigurationParam.self] = newValue }
  }

  /// The identifier of the enclosing type (contract, struct, enum, trait or event).
  public var enclosingTypeIdentifier: Identifier? {
    if let trait = traitDeclarationContext?.traitIdentifier {
      return trait
    }
    if let contractBehaviour = contractBehaviorDeclarationContext?.contractIdentifier {
      return contractBehaviour
    }
    if let structure = structDeclarationContext?.structIdentifier {
      return structure
    }
    if let contract = contractStateDeclarationContext?.contractIdentifier {
      return contract
    }
    if let enumeration = enumDeclarationContext?.enumIdentifier {
      return enumeration
    }
    if let event = eventDeclarationContext?.eventIdentifier {
      return event
    }
    return nil
  }

  /// Whether we are visiting a node in a function declaration or initializer.
  public var inFunctionOrInitializer: Bool {
    return functionDeclarationContext != nil || specialDeclarationContext != nil
  }

  // Whether we are visiting a node inside the rhs of an assignment.
  public var inAssignment: Bool {
    get { return self[IsAssignment.self] ?? false }
    set { self[IsAssignment.self] = newValue }
  }

  /// Whether we are visiting a property's default assignment.
  public var isPropertyDefaultAssignment: Bool {
    get { return self[IsPropertyDefaultAssignment.self] ?? false }
    set { self[IsPropertyDefaultAssignment.self] = newValue }
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

private struct IsInSubscriptEntry: PassContextEntry {
  typealias Value = Bool
}

private struct AsLValueContextEntry: PassContextEntry {
  typealias Value = Bool
}

private struct IsEnclosingEntry: PassContextEntry {
  typealias Value = Bool
}

private struct IsInBecomeEntry: PassContextEntry {
  typealias Value = Bool
}

private struct IsInEmitEntry: PassContextEntry {
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

private struct EnumDeclarationContextEntry: PassContextEntry {
  typealias Value = EnumDeclarationContext
}

private struct TraitDeclarationContextEntry: PassContextEntry {
  typealias Value = TraitDeclarationContext
}

private struct EventDeclarationContextEntry: PassContextEntry {
  typealias Value = EventDeclarationContext
}

private struct FunctionDeclarationContextEntry: PassContextEntry {
  typealias Value = FunctionDeclarationContext
}

private struct InitializerDeclarationContextEntry: PassContextEntry {
  typealias Value = SpecialDeclarationContext
}

private struct ScopeContextContextEntry: PassContextEntry {
  typealias Value = ScopeContext
}

private struct IsFunctionCallContextEntry: PassContextEntry {
  typealias Value = Bool
}

private struct IsExternalCallContextEntry: PassContextEntry {
  typealias Value = Bool
}

private struct IsAssignment: PassContextEntry {
  typealias Value = Bool
}

private struct IsPropertyDefaultAssignment: PassContextEntry {
  typealias Value = Bool
}

private struct IsFunctionCallArgumentLabel: PassContextEntry {
  typealias Value = Bool
}

/// See the 'isExternalConfigurationParam' property
/// External configuration params are hyper-parameters to the call, like the gas, the
/// wei used for the external call or reentrancy.
private struct IsExternalConfigurationParam: PassContextEntry {
  typealias Value = Bool
}
