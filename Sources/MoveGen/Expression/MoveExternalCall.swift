//
//  MoveExternalCall.swift
//  MoveGen
//
//  Created by Yicheng Luo on 11/14/18.
//
import AST
import Lexer
import MoveIR

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
      fatalError("normal extern call mode not implemented")
    case .returnsGracefullyOptional:
      fatalError("call? not implemented")
    case .isForced:
      return MoveFunctionCall(functionCall: functionCall, moduleName: externalCall.externalTraitName!)
        .rendered(functionContext: functionContext)
    }
  }
}
