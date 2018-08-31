//
//  IRStruct.swift
//  IRGen
//
//  Created by Franklin Schrans on 5/3/18.
//

import AST

/// Generates code for a struct. Structs functions and initializers are embedded in the contract.
public struct IRStruct {
  var structDeclaration: StructDeclaration
  var environment: Environment

  func rendered() -> String {
    // At this point, the initializers have been converted to functions.
    
    let functionsCode = structDeclaration.functionDeclarations.compactMap { functionDeclaration in
      return IRFunction(functionDeclaration: functionDeclaration, typeIdentifier: structDeclaration.identifier, environment: environment).rendered()
    }.joined(separator: "\n\n")

    return functionsCode
  }
}
