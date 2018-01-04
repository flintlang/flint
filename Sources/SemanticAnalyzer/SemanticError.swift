//
//  SemanticError.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 1/4/18.
//

import AST

enum SemanticError: Error {
  case noMatchingFunctionForFunctionCall(FunctionCall, contextCapabilities: [CallerCapability])
  case contractBehaviorDeclarationNoMatchingContract(ContractBehaviorDeclaration)
}
