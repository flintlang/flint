//
//  PropertyInformation.swift
//  AST
//
//  Created by Hails, Daniel R on 22/08/2018.
//
import Source

/// Information about a property defined in a type, such as its type and generic arguments.
public struct PropertyInformation {
  public var property: Property

  public var isConstant: Bool {
    switch property {
    case .variableDeclaration(let variableDeclaration): return variableDeclaration.isConstant
    case .enumCase(_): return true
    }
  }

  public var isAssignedDefaultValue: Bool {
    switch property {
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.assignedExpression != nil
    case .enumCase(let enumCase):
      return enumCase.hiddenValue != nil
    }
  }

  public var sourceLocation: SourceLocation? {
    switch property {
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.sourceLocation
    case .enumCase(let enumCase):
      return enumCase.sourceLocation
    }
  }

  public var rawType: RawType {
    return property.type!.rawType
  }

  public var typeGenericArguments: [RawType] {
    switch property {
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.type.genericArguments.map { $0.rawType }
    case .enumCase(_):
      return []
    }
  }
}
