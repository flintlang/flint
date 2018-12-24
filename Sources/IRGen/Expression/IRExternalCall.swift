//
//  IRExternalCall.swift
//  IRGen
//
//  Created by Yicheng Luo on 11/14/18.
//
import AST
import YUL

/// Generates code for an external call.
struct IRExternalCall {
  let externalCall: ExternalCall

  func rendered(functionContext: FunctionContext) -> YUL.Expression {
    // Hyper-parameter defaults.
    var gasExpression = Expression.inline("2300")
    var valueExpression = Expression.inline("0")

    // Hyper-parameters specified in the external call.
    for parameter in externalCall.hyperParameters {
      switch parameter.identifier!.name {
      case "gas":
        gasExpression = IRExpression(expression: parameter.expression, asLValue: false)
          .rendered(functionContext: functionContext)
      case "value":
        valueExpression = IRExpression(expression: parameter.expression, asLValue: false)
          .rendered(functionContext: functionContext)
      default:
        break
      }
    }

    // Match on the function call so we know the argument types.
    guard case .functionCall(let functionCall) = externalCall.functionCall.rhs else {
      fatalError("cannot match external call with function")
    }
    guard case .matchedFunction(let matchingFunction) =
      functionContext.environment.matchFunctionCall(functionCall,
                                                    enclosingType: functionCall.identifier.enclosingType ??
                                                      functionContext.enclosingTypeName,
                                                    typeStates: [],
                                                    callerProtections: [],
                                                    scopeContext: functionContext.scopeContext) else {
      fatalError("cannot match function signature in external call")
    }
    guard let functionSelector = (matchingFunction.declaration.externalSignatureHash?.map { [$0].toHexString() }) else {
      fatalError("cannot find function selector for function")
    }

    // Render the address of the external contract.
    let addressExpression = IRExpression(expression: externalCall.functionCall.lhs, asLValue: false)
      .rendered(functionContext: functionContext)

    // The input stack consists of three parts:
    // - function selector (4 bytes of Keccak-256 hash of the signature)
    // - static data
    // - dynamic data
    var staticSlots: [YUL.Expression] = []
    var dynamicSlots: [YUL.Expression] = []

    // This could be staticSize * 32, but this loop is necessary once
    // we have e.g. fixed-length arrays in external trait types.
    var staticSize = 0
    for parameterType in matchingFunction.parameterTypes {
      switch parameterType {
      case .solidityType:
        staticSize += 32
      default:
        fatalError("cannot use non-solidity type in external call")
      }
    }

    var dynamicSize = 0
    for (parameterType, parameter) in zip(matchingFunction.parameterTypes, functionCall.arguments) {
      switch parameterType {
      case .basicType(.string):
        // String is basic in Flint (in stack memory) but not static in Solidity
        // Flint only supports <32 byte strings, however, because they are in
        // stack, not in memory.
        staticSlots.append(Expression.inline("\(staticSize + dynamicSize)"))
        // TODO: figure out the actual length of the string at runtime (flintrocks issue #133)
        dynamicSlots.append(Expression.inline("32"))
        dynamicSlots.append(IRExpression(expression: parameter.expression, asLValue: false)
          .rendered(functionContext: functionContext))
        dynamicSize += 32
      case .basicType, .solidityType:
        staticSlots.append(IRExpression(expression: parameter.expression, asLValue: false)
          .rendered(functionContext: functionContext))
      default:
        fatalError("cannot use non-basic type in external call")
      }
    }

    let callInput = functionContext.freshVariable()

    // Render input stack storage.
    let inputSize = 4 + staticSize + dynamicSize
    var currentPosition = 4
    let slots = staticSlots + dynamicSlots

    let argumentExpressions = slots.map { (slot: YUL.Expression) -> String in
      let storedPosition = currentPosition
      currentPosition += 32
      return "mstore(add(\(callInput), \(storedPosition)), \(slot))"
    }

    // The output is simply memory suitable for the declared return type.
    let outputSize = 32

    let callSuccess = functionContext.freshVariable()
    let callOutput = functionContext.freshVariable()

    functionContext.emit(.inline("""
    let \(callInput) := flint$allocateMemory(\(inputSize))
    mstore8(\(callInput), 0x\(functionSelector[0]))
    mstore8(add(\(callInput), 1), 0x\(functionSelector[1]))
    mstore8(add(\(callInput), 2), 0x\(functionSelector[2]))
    mstore8(add(\(callInput), 3), 0x\(functionSelector[3]))
    \(argumentExpressions.joined(separator: "\n"))
    let \(callOutput) := flint$allocateMemory(\(outputSize))
    let \(callSuccess) := call(
    \(gasExpression),
    \(addressExpression),
    \(valueExpression),
    \(callInput),
    \(inputSize),
    \(callOutput),
    \(outputSize)
    )
    \(callOutput) := mload(\(callOutput))
    """))

    return Expression.catchable(value: Expression.inline(callOutput),
                                success: Expression.inline(callSuccess))
  }
}
