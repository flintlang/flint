//
//  MoveStruct.swift
//  MoveGen
//
//  Created on <check date>.
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
    let context = FunctionContext(environment: environment,
                                  scopeContext: ScopeContext(),
                                  enclosingTypeName: structDeclaration.identifier.name,
                                  isInStructFunction: true)
    let members = structDeclaration.members.compactMap { (member: StructMember) in
      switch member {
      case .variableDeclaration(let declaration):
        return MoveFieldDeclaration(variableDeclaration: declaration)
            .rendered(functionContext: context).description
      default: return nil
      }
    }.joined(separator: ",\n")

    return members.count > 0
        ? #"""
          struct \#(structDeclaration.identifier.name) {
            \#(members.indented(by: 2))
          }

          """#
        : ""
  }

  public func renderCommon() -> String {
    return #"""
           \#(renderInitializers())\#
           //// ~:   Functions    :~ ////

           \#(renderFunctions())
           """#
  }

  func renderInitializers() -> String {
    let declarations = findStructInitializers()
    guard declarations.count > 0 else {
      return ""
    }
    let initializers = declarations.map { (declaration: SpecialDeclaration) in
      MoveStructInitializer(initializerDeclaration: declaration,
                            typeIdentifier: structDeclaration.identifier,
                            propertiesInEnclosingType: structDeclaration.variableDeclarations,
                            environment: environment,
                            struct: self).rendered()
    }.reduce("") { $0 + $1 + "\n\n" }

    return #"""

           //// ~:  Initializers  :~ ////

           \#(initializers.indented(by: 0))
           """#
  }

  /// Finds the struct's public initializer, if any is declared,
  /// and returns the enclosing contract behavior declaration.
  func findStructInitializers() -> [SpecialDeclaration] {
    return structDeclaration.members.compactMap { member -> SpecialDeclaration? in
      if case .specialDeclaration(let special) = member, special.isInit {
        return special
      }
      return nil
    }
  }

  func renderFunctions() -> String {
    // At this point, the initializers and conforming functions have been converted to functions.
    let functionsCode = structDeclaration.functionDeclarations.compactMap { functionDeclaration in
      return MoveFunction(functionDeclaration: functionDeclaration,
                          typeIdentifier: structDeclaration.identifier,
                          environment: environment).rendered()
    }.joined(separator: "\n\n")

    return functionsCode
  }
}
