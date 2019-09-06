//
//  MoveExternalCall.swift
//  MoveGen
//

import AST
import Lexer
import MoveIR
import Diagnostic

/// Generates code for an external call.
struct MoveExternalCall {
  let externalCall: ExternalCall

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
    // Match on the function call so we know the argument types.
    guard case .functionCall(let functionCall) = externalCall.functionCall.rhs else {
      fatalError("cannot match external call with function")
    }

    var lookupCall = functionCall
    // remove external contract address from lookup
    lookupCall.arguments.removeFirst()
    let matched = functionContext.environment.matchFunctionCall(lookupCall,
                                                                enclosingType: functionCall.identifier.enclosingType ??
                                                                    functionContext.enclosingTypeName,
                                                                typeStates: [],
                                                                callerProtections: [],
                                                                scopeContext: functionContext.scopeContext)
    if case .matchedFunction = matched {
    } else if case .failure(let candidates) = matched,
              let candidate: CallableInformation = candidates.first,
              case .functionInformation = candidate {
    } else {
      fatalError("cannot match function signature `\(lookupCall)' in external call")
    }

    switch externalCall.mode {
    case .normal:
      Diagnostics.add(Diagnostic(
          severity: .error,
          sourceLocation: externalCall.sourceLocation,
          message: "call not yet implemented"
      ))
      Diagnostics.displayAndExit()
    case .returnsGracefullyOptional:
      Diagnostics.add(Diagnostic(
          severity: .error,
          sourceLocation: externalCall.sourceLocation,
          message: "call? not yet implemented"
      ))
      Diagnostics.displayAndExit()
    case .isForced:
      if let name = externalCall.externalTraitName,
         let type: TypeInformation = functionContext.environment.types[name],
         type.isExternalModule {
        return MoveFunctionCall(functionCall: functionCall, moduleName: externalCall.externalTraitName!)
            .rendered(functionContext: functionContext)
      } else {
        var functionCall = functionCall
        if let name = externalCall.externalTraitName {
          functionCall.mangledIdentifier = "\(name)$\(functionCall.mangledIdentifier ?? functionCall.identifier.name)"
        }
        return MoveFunctionCall(functionCall: functionCall).rendered(functionContext: functionContext)
      }
    }
  }
}
