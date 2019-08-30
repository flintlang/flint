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
  public var assignedExpression: Expression?

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
    return VariableDeclaration(modifiers: [],
                               declarationToken: Token(kind: .let, sourceLocation: sourceLocation),
                               identifier: identifier,
                               type: type,
                               assignedExpression: assignedExpression)
  }

  public init(identifier: Identifier, type: Type, implicitToken: Token?, assignedExpression: Expression?) {
    self.identifier = identifier
    self.type = type
    self.implicitToken = implicitToken
    self.assignedExpression = assignedExpression
  }

  // MARK: - ASTNode
  public var description: String {
    return "\(implicitToken?.description ?? "")\(identifier): \(type)"
  }
  public var sourceLocation: SourceLocation {
    return .spanning(identifier, to: type)
  }

  static public func constructParameter(name: String, type: RawType, sourceLocation: SourceLocation) -> Parameter {
    let identifier = Identifier(identifierToken: Token(kind: .identifier(name), sourceLocation: sourceLocation))
    return Parameter(identifier: identifier,
                     type: Type(inferredType: type,
                                identifier: identifier),
                     implicitToken: nil,
                     assignedExpression: nil)
  }

  static public func constructThisParameter(type: RawType, sourceLocation: SourceLocation) -> Parameter {
    let identifier = Identifier(identifierToken: Token(kind: .`self`, sourceLocation: sourceLocation))
    return Parameter(identifier: identifier,
                     type: Type(inferredType: .inoutType(type),
                                identifier: identifier),
                     implicitToken: nil,
                     assignedExpression: nil)
  }
}
