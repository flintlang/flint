//
//  IULIAFallback.swift
//  AST
//
//  Created by Hails, Daniel J R on 10/08/2018.
//

import AST

/// Generates code for a contract fallback.
struct IULIAContractFallback {
  var fallbackDeclaration: SpecialDeclaration
  var typeIdentifier: Identifier

  var environment: Environment

  var functionContext: FunctionContext {
    return FunctionContext(environment: environment, scopeContext: ScopeContext(), enclosingTypeName: typeIdentifier.name, isInStructFunction: false)
  }

  var parameterNames: [String] {
    return fallbackDeclaration.explicitParameters.map { parameter in
      return IULIAIdentifier(identifier: parameter.identifier).rendered(functionContext: functionContext)
    }
  }

  func rendered() -> String {
    return IULIAFunctionBody(functionDeclaration: fallbackDeclaration.asFunctionDeclaration, typeIdentifier: typeIdentifier, capabilityBinding: nil, callerCapabilities: [], environment: environment, isContractFunction: true).rendered()
  }
}

