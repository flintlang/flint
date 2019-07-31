//
//  Identifier.swift
//  YUL
//
//  Created by Aurel Bílý on 12/26/18.
//

public typealias Identifier = String

public typealias TypedIdentifier = (Identifier, Type)

func render(typedIdentifier: TypedIdentifier) -> String {
  let (ident, type) = typedIdentifier
  return "\(ident): \(type)"
}

func render(typedIdentifiers: [TypedIdentifier]) -> String { // TODO remove
  return typedIdentifiers.map({ (ident, type) in
    switch type {
    case .any:
      return "\(ident)"
    default:
      return "\(ident): \(type)"
    }
  }).joined(separator: ", ")
}
