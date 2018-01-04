//
//  SemanticError.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 1/4/18.
//

import AST
import Diagnostic

extension Diagnostic {
  static func noMatchingFunctionForFunctionCall(_ functionCall: FunctionCall, contextCallerCapabilities: [CallerCapability]) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: functionCall.sourceLocation, message: "Function \(functionCall.identifier.name) is not in scope or cannot be called using the caller capabilities \(contextCallerCapabilities.map { $0.name })")
  }

  static func contractBehaviorDeclarationNoMatchingContract(_ contractBehaviorDeclaration: ContractBehaviorDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: contractBehaviorDeclaration.contractIdentifier.sourceLocation, message: "Contract behavior declaration for \(contractBehaviorDeclaration.contractIdentifier.name) has no associated contract declaration")
  }

  static func undeclaredCallerCapability(_ callerCapability: CallerCapability, contractIdentifier: Identifier) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: callerCapability.sourceLocation, message: "Caller capability \(callerCapability.name) is undefined in \(contractIdentifier.name) or has incompatible type")
  }
}
