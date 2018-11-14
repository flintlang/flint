//
//  SemanticAnalyzer.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 12/26/17.
//

import AST
import Diagnostic

/// The `ASTPass` performing semantic analysis.
public struct SemanticAnalyzer: ASTPass {
  public init() {}

  public func postProcess(topLevelModule: TopLevelModule,
                          passContext: ASTPassContext) -> ASTPassResult<TopLevelModule> {
    var diagnostics = [Diagnostic]()
    let environment = passContext.environment!

    if !environment.hasDeclaredContract() {
      diagnostics.append(.contractNotDeclaredInModule())
    }

    // Check each declaration in the module. We check these after the TopLevelModule
    // has been processed so that we capture all definitions
    for declaration in topLevelModule.declarations {
      if case .contractDeclaration(let contractDeclaration) = declaration {
        // Check for unique public fallback
        checkUniquePublicFallback(environment: environment,
                                  contractDeclaration: contractDeclaration,
                                  diagnostics: &diagnostics)

        // Check that all trait functions are defined
        checkAllContractTraitFunctionsDefined(environment: environment,
                                              contractDeclaration: contractDeclaration,
                                              diagnostics: &diagnostics)

        // Check that all trait initialisers are defined
        checkAllContractTraitInitializersDefined(environment: environment,
                                                 contractDeclaration: contractDeclaration,
                                                 diagnostics: &diagnostics)
      }
    }

    return ASTPassResult(element: topLevelModule, diagnostics: diagnostics, passContext: passContext)
  }

  func checkUniquePublicFallback(environment: Environment,
                                 contractDeclaration: ContractDeclaration,
                                 diagnostics: inout [Diagnostic]) {
    guard environment.publicFallback(forContract: contractDeclaration.identifier.name) == nil else {
      return
    }

    let fallbacks = environment.fallbacks(in: contractDeclaration.identifier.name)
    if !fallbacks.isEmpty {
      diagnostics.append(.contractOnlyHasPrivateFallbacks(contractIdentifier: contractDeclaration.identifier,
                                                          fallbacks.map {$0.declaration}))
    }
  }

  func checkAllContractTraitFunctionsDefined(environment: Environment,
                                             contractDeclaration: ContractDeclaration,
                                             diagnostics: inout [Diagnostic]) {
    let functions = environment.undefinedFunctions(in: contractDeclaration.identifier)
    if !functions.isEmpty {
      diagnostics.append(.notImplementedFunctions(functions, in: contractDeclaration))
    }
  }

  func checkAllContractTraitInitializersDefined(environment: Environment,
                                                contractDeclaration: ContractDeclaration,
                                                diagnostics: inout [Diagnostic]) {
    let inits = environment.undefinedInitialisers(in: contractDeclaration.identifier)
    if !inits.isEmpty {
      diagnostics.append(.notImplementedInitialiser(inits, in: contractDeclaration))
    }
  }

  func addMutatingExpression(_ mutatingExpression: Expression, passContext: inout ASTPassContext) {
    let mutatingExpressions = (passContext.mutatingExpressions ?? []) + [mutatingExpression]
    passContext.mutatingExpressions = mutatingExpressions
  }
}

extension ASTPassContext {
  /// The list of mutating expressions in a function.
  var mutatingExpressions: [Expression]? {
    get { return self[MutatingExpressionContextEntry.self] }
    set { self[MutatingExpressionContextEntry.self] = newValue }
  }
}

struct MutatingExpressionContextEntry: PassContextEntry {
  typealias Value = [Expression]
}
