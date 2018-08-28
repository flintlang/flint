//
//  SpecialInformation.swift
//  AST
//
//  Created by Hails, Daniel R on 22/08/2018.
//

/// Information about an initializer/fallback.
public struct SpecialInformation {
  public var declaration: SpecialDeclaration
  public var callerCapabilities: [CallerCapability]

  var parameterTypes: [RawType] {
    return declaration.parameters.map { $0.type.rawType }
  }
}
