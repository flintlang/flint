//
//  SemanticAnalyzer.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 12/26/17.
//

import AST
import Diagnostic

public final class SemanticAnalyzer {
  var ast: TopLevelModule
  var context: Context
  var diagnostics = [Diagnostic]()

  public init(ast: TopLevelModule, context: Context) {
    self.ast = ast
    self.context = context
  }

  public func analyze() -> [Diagnostic] {
    visit(ast)
    return diagnostics
  }

  func addDiagnostic(fromError error: Error) {
    diagnostics.append(diagnostic(from: error))
  }

  private func diagnostic(from error: Error) -> Diagnostic {
    switch error {
    case SemanticError.noMatchingFunctionForFunctionCall(let functionCall, let contextCallerCapabilities):
      return Diagnostic(severity: .error, sourceLocation: functionCall.sourceLocation, message: "Function \(functionCall.identifier.name) is not in scope or cannot be called using the caller capabilities \(contextCallerCapabilities.map { $0.name })")
    case SemanticError.contractBehaviorDeclarationNoMatchingContract(let contractBehaviorDeclaration):
      return Diagnostic(severity: .error, sourceLocation: contractBehaviorDeclaration.contractIdentifier.sourceLocation, message: "Contract behavior declaration for \(contractBehaviorDeclaration.contractIdentifier.name) has no associated contract declaration")
    case SemanticError.undeclaredCallerCapability(let callerCapability, let contractIdentifier):
      return Diagnostic(severity: .error, sourceLocation: callerCapability.sourceLocation, message: "Caller capability \(callerCapability.name) is undefined in \(contractIdentifier.name) or has incompatible type")
    default: fatalError()
    }
  }
}
