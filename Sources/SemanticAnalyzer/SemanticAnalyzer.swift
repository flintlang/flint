//
//  SemanticAnalyzer.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 12/26/17.
//

import AST
import Diagnostic

public struct SemanticAnalyzer {
  var ast: TopLevelModule
  var context: Context
  var diagnostics = [Diagnostic]()

  public init(ast: TopLevelModule, context: Context) {
    self.ast = ast
    self.context = context
  }

  public func analyze() -> [Diagnostic] {
    do {
     try visit(ast)
    } catch SemanticError.noMatchingFunctionForFunctionCall(let functionCall, let contextCallerCapabilities) {
      return [Diagnostic(severity: .error, sourceLocation: functionCall.sourceLocation, message: "Function \(functionCall.identifier.name) is not in scope or cannot be called using the caller capabilities \(contextCallerCapabilities.map { $0.name })")]
    } catch SemanticError.contractBehaviorDeclarationNoMatchingContract(let contractBehaviorDeclaration) {
      return [Diagnostic(severity: .error, sourceLocation: contractBehaviorDeclaration.contractIdentifier.sourceLocation, message: "Contract behavior declaration for \(contractBehaviorDeclaration.contractIdentifier.name) has no associated contract declaration")]
    } catch {
      fatalError()
    }

    return []
  }
}
