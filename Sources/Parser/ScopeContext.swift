//
//  ScopeContext.swift
//  Parser
//
//  Created by Franklin Schrans on 1/5/18.
//

import AST

struct ScopeContext {
  var localVariables = [Identifier]()
  var contractIdentifier: Identifier

  init(localVariables: [Identifier] = [], contractIdentifier: Identifier) {
    self.localVariables = localVariables
    self.contractIdentifier = contractIdentifier
  }

  mutating func merge(with otherScopeContext: ScopeContext) {
    localVariables.append(contentsOf: otherScopeContext.localVariables)
  }

  mutating func addLocalVariable(_ localVariable: Identifier) {
    localVariables.append(localVariable)
  }

  func contains(localVariable: String) -> Bool {
    return localVariables.contains { $0.name == localVariable }
  }
}
