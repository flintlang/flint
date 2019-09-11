//
//  FunctionCallCompleter.swift
//  MoveGen
//
//

import AST
import Lexer

/// A prepocessing step to add parameters with default values in function declarations to the actual function calls

public struct FunctionCallCompleter: ASTPass {
  public init() {}

  // MARK: FunctionCall
  public func process(functionCall: FunctionCall,
                      passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    let environment = passContext.environment!
    var functionCall = functionCall
    let enclosingType = passContext.enclosingTypeIdentifier!.name

    if case .matchedEvent(let eventInformation) =
      environment.matchEventCall(functionCall,
                                 enclosingType: enclosingType,
                                 scopeContext: passContext.scopeContext ?? ScopeContext()) {

      functionCall.arguments = add(declarationParameters: eventInformation.declaration.variableDeclarations,
                                   to: functionCall)

      return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
    }

    if case .matchedFunction(let functionInformation) =
      environment.matchFunctionCall(functionCall,
                                    enclosingType: enclosingType,
                                    typeStates: [],
                                    callerProtections: [],
                                    scopeContext: passContext.scopeContext ?? ScopeContext()) {

      let functionSignature = functionInformation.declaration.signature
      functionCall.arguments = add(declarationParameters: functionSignature.parameters.map { $0.asVariableDeclaration },
                                   to: functionCall)

      return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
    }

    return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
  }

  // Adds the defaulted parameters to a function call given all the declared parameters of a function
  // This assumes parameters are valid, ie. they were already determined to be a match and they follow
  // the following rule: all default parameters must be declared at the end of the function signature
  private func add(declarationParameters: [VariableDeclaration], to functionCall: FunctionCall) -> [FunctionArgument] {
    var declarationIndex = 0
    var existingArguments = functionCall.arguments

    while declarationIndex < declarationParameters.count {
      let currentParameter = declarationParameters[declarationIndex]

      if declarationIndex == existingArguments.count {
        // Add everything that's remaining, which should only be optional parameters
        existingArguments.insert(FunctionArgument(identifier: currentParameter.identifier,
                                                  expression: currentParameter.assignedExpression!),
                                 at: declarationIndex)

        declarationIndex += 1
        continue
      }

      guard let argumentIdentifier = existingArguments[declarationIndex].identifier else {
        // Identifier-less call parameters should always match the declaration parameter
        declarationIndex += 1

        continue
      }

      guard let assignedExpression = currentParameter.assignedExpression else {
        // Parameter must have been provided
        declarationIndex += 1

        continue
      }

      if currentParameter.identifier.name == argumentIdentifier.name {
        // Default parameter value is overridden
        declarationIndex += 1

        continue
      }

      existingArguments.insert(FunctionArgument(identifier: currentParameter.identifier,
                                                expression: assignedExpression),
                               at: declarationIndex)

      declarationIndex += 1
    }

    return existingArguments
  }
}
