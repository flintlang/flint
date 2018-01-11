//
//  TypeError.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 1/11/18.
//

import AST
import Diagnostic

extension Diagnostic {
  static func incompatibleReturnType(_ type: Type, expectedType: Type) -> Diagnostic {
    return .incompatibleType(type, expectedType: expectedType, useContext: "return")
  }

  static func incompatibleArgumentType(_ type: Type, expectedType: Type) -> Diagnostic {
    return .incompatibleType(type, expectedType: expectedType, useContext: "argument")
  }

  private static func incompatibleType(_ type: Type, expectedType: Type, useContext: String) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: type.sourceLocation, message: "Cannot convert expression of type \(type.name) to expected \(useContext) type \(expectedType.name)")
  }
}
