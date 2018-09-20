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
  public var isSignature: Bool

  var parameterTypes: [RawType] {
    return declaration.signature.parameters.map { $0.type.rawType }
  }

  var parameterIdentifiers: [Identifier] {
    return declaration.signature.parameters.map { $0.identifier }
  }

  var resultType: RawType {
    return declaration.signature.rawType
  }
}
