//
//  VariableDeclaration.swift
//  flintc
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

/// The declaration of a variable or constant, either as a state property of a local variable.
public struct VariableDeclaration: SourceEntity {
  public var declarationToken: Token?
  public var identifier: Identifier
  public var type: Type
  public var isConstant: Bool
  public var assignedExpression: Expression?

  public var sourceLocation: SourceLocation {
    if let declarationToken = declarationToken {
      return .spanning(declarationToken, to: type)
    }
    return .spanning(identifier, to: type)
  }

  public init(declarationToken: Token?, identifier: Identifier, type: Type, isConstant: Bool = false, assignedExpression: Expression? = nil) {
    self.declarationToken = declarationToken
    self.identifier = identifier
    self.type = type
    self.isConstant = isConstant
    self.assignedExpression = assignedExpression
  }
}
