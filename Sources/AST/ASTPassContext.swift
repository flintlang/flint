//
//  PassContext.swift
//  AST
//
//  Created by Franklin Schrans on 1/16/18.
//

public struct ASTPassContext {
  var storage = [AnyHashable: Any]()

  public init() {}

  public subscript<Entry: PassContextEntry>(_ contextEntry: Entry.Type) -> Entry.Value? {
    get { return storage[contextEntry.hashValue] as? Entry.Value }
    set { storage[contextEntry.hashValue] = newValue }
  }

  public func withUpdates(updates: (inout ASTPassContext) -> ()) -> ASTPassContext {
    var copy = self
    updates(&copy)
    return copy
  }
}

extension ASTPassContext {
  public var environment: Environment? {
    get { return self[EnvironmentContextEntry.self] }
    set { self[EnvironmentContextEntry.self] = newValue }
  }

  public var asLValue: Bool? {
    get { return self[AsLValueContextEntry.self] }
    set { self[AsLValueContextEntry.self] = newValue }
  }

  public var contractBehaviorDeclarationContext: ContractBehaviorDeclarationContext? {
    get { return self[ContractBehaviorDeclarationContextEntry.self] }
    set { self[ContractBehaviorDeclarationContextEntry.self] = newValue }
  }

  public var functionDeclarationContext: FunctionDeclarationContext? {
    get { return self[FunctionDeclarationContextEntry.self] }
    set { self[FunctionDeclarationContextEntry.self] = newValue }
  }

  public var scopeContext: ScopeContext? {
    get { return self[ScopeContextContextEntry.self] }
    set { self[ScopeContextContextEntry.self] = newValue }
  }

  public var isFunctionCall: Bool? {
    get { return self[IsFunctionCallContextEntry.self] }
    set { self[IsFunctionCallContextEntry.self] = newValue }
  }
}

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

private struct ContractBehaviorDeclarationContextEntry: PassContextEntry {
  typealias Value = ContractBehaviorDeclarationContext
}

private struct FunctionDeclarationContextEntry: PassContextEntry {
  typealias Value = FunctionDeclarationContext
}

private struct ScopeContextContextEntry: PassContextEntry {
  typealias Value = ScopeContext
}

private struct IsFunctionCallContextEntry: PassContextEntry {
  typealias Value = Bool
}
