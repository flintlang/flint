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
    guard case .matchedFunction(let matchingFunction) =
      functionContext.environment.matchFunctionCall(lookupCall,
                                                    enclosingType: functionCall.identifier.enclosingType ??
                                                      functionContext.enclosingTypeName,
                                                    typeStates: [],
                                                    callerProtections: [],
                                                    scopeContext: functionContext.scopeContext) else {
      fatalError("cannot match function signature in external call")
    }

    matchingFunction.parameterTypes.forEach { paremeterType in
      switch paremeterType {
      case .basicType, .externalType:
        break
      default:
        fatalError("cannot use non-basic type in external call")
      }
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
