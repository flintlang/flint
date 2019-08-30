//
//  Identifier.swift
//  YUL
//
//  Created by Aurel Bílý on 12/26/18.
//

public typealias Identifier = String

public typealias TypedIdentifier = (Identifier, Type)

public enum Transfer: CustomStringConvertible {
  case move(Expression)
  case copy(Expression)

  public var description: String {
    switch self {
    case .move(let expression): return "move(\(expression))"
    case .copy(let expression): return "copy(\(expression))"
    }
  }
}

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
