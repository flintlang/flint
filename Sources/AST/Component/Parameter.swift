//
//  Parameter.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Source
import Lexer

/// The parameter of a function.
public struct Parameter: ASTNode {
  public var identifier: Identifier
  public var type: Type

  public var implicitToken: Token?

  public var isImplicit: Bool {
    return implicitToken != nil
  }

  public var isInout: Bool {
    if case .inoutType = type.rawType {
      return true
    }

    return false
  }

  /// Whether the parameter is both `implicit` and has a currency type.
  public var isPayableValueParameter: Bool {
    if isImplicit, type.isCurrencyType {
      return true
    }
    return false
  }

  public var asVariableDeclaration: VariableDeclaration {
    return VariableDeclaration(modifiers: [], declarationToken: Token(kind: .let, sourceLocation: sourceLocation), identifier: identifier, type: type)
  }

  public init(identifier: Identifier, type: Type, implicitToken: Token?) {
    self.identifier = identifier
    self.type = type
    self.implicitToken = implicitToken
  }

  // MARK: - ASTNode
  public var description: String {
    return "\(implicitToken?.description ?? "")\(identifier): \(type)"
  }
  public var sourceLocation: SourceLocation {
    return .spanning(identifier, to: type)
  }
}
