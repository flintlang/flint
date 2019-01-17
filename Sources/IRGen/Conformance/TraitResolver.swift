//
//  TraitResolver.swift
//  IRGen
//
//  Created by Niklas Vangerow on 20/10/2018.
//

import AST
import Lexer

/// A prepocessing step to update the program's AST before code generation, specifically in order to resolve Self
/// Copies defaulted struct trait declarations into their conforming struct types.

public struct TraitResolver: ASTPass {
  public init() {}

  // MARK: Declaration
  public func process(structDeclaration: StructDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<StructDeclaration> {
    let environment = passContext.environment!
    var structDeclaration = structDeclaration

    let conformingFunctions = environment.conformingFunctions(in: structDeclaration.identifier.name)
      .compactMap { functionInformation -> StructMember in
        var functionDeclaration = functionInformation.declaration
        functionDeclaration.scopeContext = ScopeContext()

        return .functionDeclaration(functionDeclaration)
    }

    structDeclaration.members += conformingFunctions

    return ASTPassResult(element: structDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(traitDeclaration: TraitDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<TraitDeclaration> {
    var traitDeclaration = traitDeclaration
    // Replace trait members with empty list as we NEEDN'T process the trait (IR does not get generated).
    // This was necessary as this subtree does unnecessary type checking and breaks with the addition of Self.
    traitDeclaration.members = []
    return ASTPassResult(element: traitDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(functionDeclaration: FunctionDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    // Convert Self to struct type, if defined in struct
    if let structDeclarationContext = passContext.structDeclarationContext {
      var functionDeclaration = functionDeclaration

      functionDeclaration.signature.parameters =
        functionDeclaration.signature.parameters.map { (parameter) -> Parameter in
          let type = parameter.type.rawType

          if type.isSelfType {
            var parameter = parameter
            let structType: RawType = .userDefinedType(structDeclarationContext.structIdentifier.name)

            if type.isInout {
              parameter.type.rawType = .inoutType(structType)
            } else {
              parameter.type.rawType = structType
            }

            return parameter
          }

          return parameter
        }

      // We update the passContext with a new function as the signature has changed.
      let newPassContext = passContext.withUpdates { (context) in
          context.environment!.addFunction(functionDeclaration,
                                           enclosingType: structDeclarationContext.structIdentifier.name,
                                           states: [], callerProtections: [])
        }

      return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: newPassContext)
    }

    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(variableDeclaration: VariableDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    var variableDeclaration = variableDeclaration

    if let structDeclarationContext = passContext.structDeclarationContext,
      variableDeclaration.type.rawType.isSelfType {
      variableDeclaration.type.rawType = .userDefinedType(structDeclarationContext.structIdentifier.name)
    }

    return ASTPassResult(element: variableDeclaration, diagnostics: [], passContext: passContext)
  }
}
