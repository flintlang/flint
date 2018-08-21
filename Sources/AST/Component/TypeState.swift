//
//  TypeState.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

public struct TypeState: SourceEntity {
  public var identifier: Identifier

  public var sourceLocation: SourceLocation {
    return identifier.sourceLocation
  }

  public var name: String {
    return identifier.name
  }

  public var isAny: Bool {
    return name == "any"
  }

  public init(identifier: Identifier) {
    self.identifier = identifier
  }

  public func isSubState(of parent: TypeState) -> Bool {
    return parent.isAny || name == parent.name
  }
}

