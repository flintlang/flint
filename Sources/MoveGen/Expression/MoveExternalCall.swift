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
    //guard case .functionCall(let functionCall) = externalCall.functionCall else {
    //  fatalError("cannot match external call with function")
    //}
    //return MoveExpression(expression: .functionCall(functionCall)).rendered(functionContext: functionContext)
    return MoveExpression(expression: .binaryExpression(externalCall.functionCall))
      .rendered(functionContext: functionContext)
    /*var lookupCall = functionCall
    if let first: FunctionArgument = functionCall.arguments.first,
      case .`self` = first.expression {
      lookupCall.arguments.remove(at: 0)
    }
    guard case .matchedFunction(let matchingFunction) =
      functionContext.environment.matchFunctionCall(lookupCall,
                                                    enclosingType: functionCall.identifier.enclosingType ??
                                                      functionContext.enclosingTypeName,
                                                    typeStates: [],
                                                    callerProtections: [],
                                                    scopeContext: functionContext.scopeContext) else {
      fatalError("cannot match function signature in external call")
    }

    // Render the address of the external contract.
    let addressExpression = MoveExpression(expression: externalCall.functionCall.lhs)
      .rendered(functionContext: functionContext)
    var args: [MoveIR.Expression] = []
    for (parameterType, parameter) in zip(matchingFunction.parameterTypes, functionCall.arguments) {
      switch parameterType {
      case .basicType, .externalType:
        args.append(MoveExpression(expression: parameter.expression).rendered(functionContext: functionContext))
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
      return MoveExpression(expression: externalCall.functionCall.rhs).rendered(functionContext: functionContext)
    }
    */
  }
}
