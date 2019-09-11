//
//  MoveFallback.swift
//  AST
//
//

import AST

/// Generates code for a contract fallback.
struct MoveContractFallback {
  var fallbackDeclaration: SpecialDeclaration
  var typeIdentifier: Identifier

  var environment: Environment

  var functionContext: FunctionContext {
    return FunctionContext(environment: environment,
                           scopeContext: ScopeContext(),
                           enclosingTypeName: typeIdentifier.name,
                           isInStructFunction: false)
  }

  var parameterNames: [String] {
    return fallbackDeclaration.explicitParameters.map { parameter in
      return MoveIdentifier(identifier: parameter.identifier).rendered(functionContext: functionContext).description
    }
  }

  func rendered() -> String {
    return MoveFunctionBody(functionDeclaration: fallbackDeclaration.asFunctionDeclaration,
                          typeIdentifier: typeIdentifier,
                          callerBinding: nil,
                          callerProtections: [],
                          environment: environment,
                          isContractFunction: true).rendered()
  }
}
