//
//  SpecialInformation.swift
//  AST
//
//  Created by Hails, Daniel R on 22/08/2018.
//

/// Information about an initializer/fallback.
public struct SpecialInformation {
  public var declaration: SpecialDeclaration
  public var callerProtections: [CallerProtection]
  public var isSignature: Bool

  var parameterTypes: [RawType] {
    return declaration.signature.parameters.map { $0.type.rawType }
  }
}
