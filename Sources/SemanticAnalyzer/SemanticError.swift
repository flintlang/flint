//
//  SemanticError.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 1/4/18.
//

import AST

enum SemanticError: Error {
  case invalidFunctionCall(FunctionCall)
  case invalidContractBehaviorDeclaration(ContractBehaviorDeclaration)
}
