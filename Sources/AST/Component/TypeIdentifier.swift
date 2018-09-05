//
//  TypeIdentifier.swift
//  AST
//
//  Created by Hails, Daniel R on 31/08/2018.
//

import Source
import Lexer

/// A type annotation for a variable.
public struct TypeIdentifier: ASTNode {
  public let name: Identifier
  public let genericArguments: [TypeIdentifier]

  public init(name: Identifier, genericArguments: [TypeIdentifier] = []) {
    self.name = name
    self.genericArguments = genericArguments
  }

  // MARK: - ASTNode
  public var description: String {
    return "\(name)<\(genericArguments.map({ $0.description }).joined(separator: ", "))>"
  }
  public var sourceLocation: SourceLocation {
    if genericArguments.isEmpty {
      return name.sourceLocation
    }
    return .spanning(name, to: genericArguments.last!)
  }
}
