//
//  EventInformation.swift
//  AST
//
//  Created by Hails, Daniel R on 29/08/2018.
//

/// Information about an event
public struct EventInformation {
  public var declaration: EventDeclaration

  public var eventTypes: [RawType] {
    return declaration.variableDeclarations.map { $0.type.rawType }
  }

  public var parameterIdentifiers: [Identifier] {
    return declaration.variableDeclarations.map { $0.identifier }
  }

  public var requiredParameterIdentifiers: [Identifier] {
    return declaration.variableDeclarations.filter({ $0.assignedExpression == nil }).map({ $0.identifier })
  }
}
