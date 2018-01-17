//
//  PassContext.swift
//  AST
//
//  Created by Franklin Schrans on 1/16/18.
//

public struct ASTPassContext {
  private var storage = [AnyHashable: Any]()

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
  public var context: Context? {
    get {
      return self[ContextPassContextEntry.self]
    }
    set {
      self[ContextPassContextEntry.self] = newValue
    }
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

private struct ContextPassContextEntry: PassContextEntry {
  typealias Value = Context
}
