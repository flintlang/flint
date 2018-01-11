//
//  ScopeContext.swift
//  Parser
//
//  Created by Franklin Schrans on 1/5/18.
//

import AST

struct ScopeContext {
  var localVariables = [VariableDeclaration]()
  var contractIdentifier: Identifier

  init(localVariables: [VariableDeclaration] = [], contractIdentifier: Identifier) {
    self.localVariables = localVariables
    self.contractIdentifier = contractIdentifier
  }

  mutating func merge(with otherScopeContext: ScopeContext) {
    localVariables.append(contentsOf: otherScopeContext.localVariables)
  }

  mutating func addLocalVariable(_ localVariable: VariableDeclaration) {
    localVariables.append(localVariable)
  }

  func contains(localVariable: String) -> Bool {
    return localVariables.contains { $0.identifier.name == localVariable }
  }
}
