//
//  IRStruct.swift
//  IRGen
//
//  Created by Franklin Schrans on 5/3/18.
//

import AST

import Foundation
import Source
import Lexer

/// Generates code for a struct. Structs functions and initializers are embedded in the contract.
public struct IRStruct {
  var structDeclaration: StructDeclaration
  var environment: Environment

  func constructParameter(name: String, type: RawType, sourceLocation: SourceLocation) -> Parameter {
    let identifier = Identifier(identifierToken: Token(kind: .identifier(name), sourceLocation: sourceLocation))
    return Parameter(identifier: identifier, type: Type(inferredType: type, identifier: identifier), implicitToken: nil)
  }

  func rendered() -> String {
    // At this point, the initializers have been converted to functions.

    let conformingFunctionsCode = environment.conformingFunctions(in: structDeclaration.identifier.name).compactMap { functionInformation in
      // TODO: fix this hack?
      var functionDeclaration = functionInformation.declaration

      functionDeclaration.scopeContext = ScopeContext()

      // Mangle function name
      let parameters = functionDeclaration.signature.parameters.map { $0.type.rawType }
      functionDeclaration.mangledIdentifier = Mangler.mangleFunctionName(functionDeclaration.identifier.name, parameterTypes: parameters, enclosingType: structDeclaration.identifier.name)

      // Add parameters.
      let parameter = constructParameter(name: "flintSelf", type: .inoutType(.userDefinedType(structDeclaration.identifier.name)), sourceLocation: functionDeclaration.sourceLocation)
      functionDeclaration.signature.parameters.insert(parameter, at: 0)

      let dynamicParameters = functionDeclaration.signature.parameters.enumerated().filter { $0.1.type.rawType.isDynamicType }

      var offset = 0
      for (index, parameter) in dynamicParameters where !parameter.isImplicit {
        let isMemParameter = constructParameter(name: Mangler.isMem(for: parameter.identifier.name), type: .basicType(.bool), sourceLocation: parameter.sourceLocation)
        functionDeclaration.signature.parameters.insert(isMemParameter, at: index + 1 + offset)
        offset += 1
      }
      functionDeclaration.scopeContext?.parameters = functionDeclaration.signature.parameters

      return IRFunction(functionDeclaration: functionDeclaration, typeIdentifier: structDeclaration.identifier, environment: environment).rendered()
    }.joined(separator: "\n\n")

    let functionsCode = structDeclaration.functionDeclarations.compactMap { functionDeclaration in
      return IRFunction(functionDeclaration: functionDeclaration, typeIdentifier: structDeclaration.identifier, environment: environment).rendered()
    }.joined(separator: "\n\n")

    return "\(conformingFunctionsCode)\n\n\(functionsCode)"
  }
}
