//
//  VisitorContext.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 1/11/18.
//

import AST

struct ContractBehaviorDeclarationContext {
  var contractIdentifier: Identifier
  var contractProperties: [VariableDeclaration]
  var callerCapabilities: [CallerCapability]

  func isPropertyDeclared(_ name: String) -> Bool {
    return contractProperties.contains { $0.identifier.name == name }
  }
}


struct FunctionDeclarationContext {
  var declaration: FunctionDeclaration
  var contractContext: ContractBehaviorDeclarationContext

  var isMutating: Bool {
    return declaration.isMutating
  }
}
