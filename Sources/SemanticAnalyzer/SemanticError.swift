//
//  SemanticError.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 1/4/18.
//

import AST
import Diagnostic

// MARK: Errors

extension Diagnostic {
  static func noMatchingFunctionForFunctionCall(_ functionCall: FunctionCall, contextCallerCapabilities: [CallerCapability]) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: functionCall.sourceLocation, message: "Function \(functionCall.identifier.name) is not in scope or cannot be called using the caller capabilities \(contextCallerCapabilities.map { $0.name })")
  }

  static func contractBehaviorDeclarationNoMatchingContract(_ contractBehaviorDeclaration: ContractBehaviorDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: contractBehaviorDeclaration.sourceLocation, message: "Contract behavior declaration for \(contractBehaviorDeclaration.contractIdentifier.name) has no associated contract declaration")
  }

  static func undeclaredCallerCapability(_ callerCapability: CallerCapability, contractIdentifier: Identifier) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: callerCapability.sourceLocation, message: "Caller capability \(callerCapability.name) is undefined in \(contractIdentifier.name) or has incompatible type")
  }

  static func useOfMutatingExpressionInNonMutatingFunction(_ expression: Expression, functionDeclaration: FunctionDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: expression.sourceLocation, message: "Use of mutating statement in a nonmutating function")
  }

  static func useOfUndeclaredIdentifier(_ identifier: Identifier) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: identifier.sourceLocation, message: "Use of undeclared identifier \(identifier.name)")
  }

  static func unexpectedReturnInVoidFunction(_ statement: Statement) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: statement.sourceLocation, message: "Unexpected return in void function")
  }

  static func missingReturnInNonVoidFunction(closeBraceToken: Token, resultType: Type) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: closeBraceToken.sourceLocation, message: "Missing return in function expected to return \(resultType.name)")
  }
}

// MARK: Warnings

extension Diagnostic {
  static func codeAfterReturn(_ statement: Statement) -> Diagnostic {
    return Diagnostic(severity: .warning, sourceLocation: statement.sourceLocation, message: "Code after return will never be executed")
  }
}
