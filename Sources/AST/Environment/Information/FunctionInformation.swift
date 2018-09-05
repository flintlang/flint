//
//  FunctionInformation.swift
//  AST
//
//  Created by Hails, Daniel R on 22/08/2018.
//

/// Information about a function, such as which caller capabilities it requires and if it is mutating.
public struct FunctionInformation {
  public var declaration: FunctionDeclaration
  public var typeStates: [TypeState]
  public var callerCapabilities: [CallerCapability]
  public var isMutating: Bool

  var parameterTypes: [RawType] {
    return declaration.parameters.map { $0.type.rawType }
  }

  var parameterIdentifiers: [Identifier] {
    return declaration.parameters.map { $0.identifier }
  }

  var resultType: RawType {
    return declaration.rawType
  }
}
