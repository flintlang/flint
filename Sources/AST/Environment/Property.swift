//
//  Property.swift
//  AST
//
//  Created by Hails, Daniel J R on 22/08/2018.
//
import Source

public enum Property {
  case variableDeclaration(VariableDeclaration)
  case enumCase(EnumCase)

  public var identifier: Identifier {
    switch self {
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.identifier
    case .enumCase(let enumCase):
      return enumCase.identifier
    }
  }

  public var value: Expression? {
    switch self {
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.assignedExpression
    case .enumCase(let enumCase):
      return enumCase.hiddenValue
    }
  }

  public var type: Type? {
    switch self {
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.type
    case .enumCase(let enumCase):
      return enumCase.type
    }
  }

  public var sourceLocation: SourceLocation {
    switch self {
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.sourceLocation
    case .enumCase(let enumCase):
      return enumCase.sourceLocation
    }
  }
}
