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

  public func postProcess(topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule> {
    var diagnostics = [Diagnostic]()
    let environment = passContext.environment!

    if !environment.hasDeclaredContract() {
      diagnostics.append(.contractNotDeclaredInModule())
    }
    for declaration in topLevelModule.declarations {
      if case .contractDeclaration(let contractDeclaration) = declaration,
        passContext.environment!.publicFallback(forContract: contractDeclaration.identifier.name) == nil {
        let fallbacks = passContext.environment!.fallbacks(in: contractDeclaration.identifier.name)
        if !fallbacks.isEmpty {
          diagnostics.append(.contractOnlyHasPrivateFallbacks(contractIdentifier: contractDeclaration.identifier, fallbacks.map{$0.declaration}))
        }
      }
    }
    return ASTPassResult(element: topLevelModule, diagnostics: diagnostics, passContext: passContext)
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
