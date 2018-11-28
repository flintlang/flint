//
//  FunctionInformation.swift
//  AST
//
//  Created by Hails, Daniel R on 22/08/2018.
//

/// Information about a function, such as which caller protections it requires and if it is mutating.
public struct FunctionInformation {
  public var declaration: FunctionDeclaration
  public var typeStates: [TypeState]
  public var callerProtections: [CallerProtection]
  public var isMutating: Bool
  public var isSignature: Bool

  public var parameterTypes: [RawType] {
    return declaration.signature.parameters.rawTypes
  }

  var parameterIdentifiers: [Identifier] {
    return declaration.signature.parameters.map { $0.identifier }
  }

  var resultType: RawType {
    return declaration.signature.rawType
  }

  var requiredParameterIdentifiers: [Identifier] {
    return declaration.signature.parameters.filter { $0.assignedExpression == nil }.map { $0.identifier }
  }
}
