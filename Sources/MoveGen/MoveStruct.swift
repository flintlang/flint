//
//  MoveStruct.swift
//  MoveGen
//
//  Created by Franklin Schrans on 5/3/18.
//

import AST

import Foundation
import Source
import Lexer

/// Generates code for a struct. Structs functions and initializers are embedded in the contract.
public struct MoveStruct {
  var structDeclaration: StructDeclaration
  var environment: Environment

  func rendered() -> String {
    // At this point, the initializers and conforming functions have been converted to functions.
    let functionsCode = structDeclaration.functionDeclarations.compactMap { functionDeclaration in
      return MoveFunction(functionDeclaration: functionDeclaration,
                        typeIdentifier: structDeclaration.identifier,
                        environment: environment).rendered()
    }.joined(separator: "\n\n")

    return functionsCode
  }
}
