//
//  IRExternalCall.swift
//  IRGen
//
//  Created by Yicheng Luo on 11/14/18.
//
import AST
import Lexer
import YUL

/// Generates code for an external call.
struct IRExternalCall {
  let externalCall: ExternalCall

  func rendered(functionContext: FunctionContext) -> YUL.Expression {
    // Hyper-parameter defaults.
    var gasExpression = YUL.Expression.literal(.num(2300))
    var valueExpression = YUL.Expression.literal(.num(0))

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
      case .externalType:
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
        staticSlots.append(YUL.Expression.literal(.num(staticSize + dynamicSize)))
        // TODO: figure out the actual length of the string at runtime (flintrocks issue #133)
        dynamicSlots.append(YUL.Expression.literal(.num(32)))
        dynamicSlots.append(IRExpression(expression: parameter.expression, asLValue: false)
          .rendered(functionContext: functionContext))
        dynamicSize += 32
      case .basicType, .externalType:
        staticSlots.append(IRExpression(expression: parameter.expression, asLValue: false)
          .rendered(functionContext: functionContext))
      default:
        fatalError("cannot use non-basic type in external call")
      }
    }

    let callInput = functionContext.freshVariable()

    // Render input stack storage.
    let inputSize = 4 + staticSize + dynamicSize
    let slots = staticSlots + dynamicSlots

    // The output is simply memory suitable for the declared return type.
    let outputSize = 32

    let callSuccess = functionContext.freshVariable()
    let callOutput = functionContext.freshVariable()

    functionContext.emit(.expression(.variableDeclaration(
      VariableDeclaration([(callInput, .any)], IRRuntimeFunction.allocateMemory(size: inputSize))
    )))
    functionContext.emit(.expression(.functionCall(
      FunctionCall("mstore8", .identifier(callInput), .literal(.hex("0x\(functionSelector[0])")))
    )))
    functionContext.emit(.expression(.functionCall(
      FunctionCall("mstore8", .functionCall(FunctionCall("add", .identifier(callInput), .literal(.num(1)))),
                              .literal(.hex("0x\(functionSelector[1])")))
    )))
    functionContext.emit(.expression(.functionCall(
      FunctionCall("mstore8", .functionCall(FunctionCall("add", .identifier(callInput), .literal(.num(2)))),
                              .literal(.hex("0x\(functionSelector[2])")))
    )))
    functionContext.emit(.expression(.functionCall(
      FunctionCall("mstore8", .functionCall(FunctionCall("add", .identifier(callInput), .literal(.num(3)))),
                              .literal(.hex("0x\(functionSelector[3])")))
    )))

    var currentPosition = 4
    slots.forEach {
      functionContext.emit(.expression(.functionCall(
        FunctionCall("mstore", .functionCall(FunctionCall("add",
                                             .identifier(callInput), .literal(.num(currentPosition)))), $0)
      )))
      currentPosition += 32
    }

    functionContext.emit(.expression(.variableDeclaration(
      VariableDeclaration([(callOutput, .any)], IRRuntimeFunction.allocateMemory(size: outputSize))
    )))

    let previousStateVariable = saveTypeState(functionContext)
    enterProtectorTypeState(functionContext)

    functionContext.emit(.expression(.variableDeclaration(
      VariableDeclaration([(callSuccess, .any)], .functionCall(FunctionCall("call",
        gasExpression,
        addressExpression,
        valueExpression,
        .identifier(callInput),
        .literal(.num(inputSize)),
        .identifier(callOutput),
        .literal(.num(outputSize))
      )))
    )))

    restoreTypeState(functionContext, savedVariableName: previousStateVariable)

    functionContext.emit(.expression(.assignment(
      Assignment([callOutput], .functionCall(FunctionCall("mload", .identifier(callOutput))))
    )))

    switch externalCall.mode {
    case .normal:
      return .catchable(value: .identifier(callOutput), success: .identifier(callSuccess))
    case .returnsGracefullyOptional:
      fatalError("call? not implemented")
    case .isForced:
      return .identifier(callOutput)
    }
  }

  func saveTypeState(_ functionContext: FunctionContext) -> String {
    let savedVariableName = functionContext.freshVariable()

    let stateVariable: AST.Expression = .identifier(
      Identifier(name: IRContract.stateVariablePrefix + functionContext.enclosingTypeName,
                 sourceLocation: .DUMMY))
    let selfState: AST.Expression = .binaryExpression(
      BinaryExpression(lhs: .self(Token(kind: .self, sourceLocation: .DUMMY)),
                       op: Token(kind: .punctuation(.dot), sourceLocation: .DUMMY),
                       rhs: stateVariable))
    let stateVariableRendered = IRExpression(expression: selfState, asLValue: false)
      .rendered(functionContext: functionContext)

    functionContext.emit(.expression(.variableDeclaration(
      VariableDeclaration([(savedVariableName, .any)],
                          .inline(stateVariableRendered.description))
    )))

    return savedVariableName
  }

  func enterProtectorTypeState(_ functionContext: FunctionContext) {
    let stateVariable: AST.Expression = .identifier(
      Identifier(name: IRContract.stateVariablePrefix + functionContext.enclosingTypeName,
                 sourceLocation: .DUMMY))
    let selfState: AST.Expression = .binaryExpression(
      BinaryExpression(lhs: .self(Token(kind: .self, sourceLocation: .DUMMY)),
                       op: Token(kind: .punctuation(.dot), sourceLocation: .DUMMY),
                       rhs: stateVariable))
    let stateVariableRendered = IRExpression(expression: selfState, asLValue: true)
      .rendered(functionContext: functionContext)

    functionContext.emit(.expression(
      IRRuntimeFunction.store(address: stateVariableRendered,
                              value: .inline("\(IRContract.reentrancyProtectorValue)"),
                              inMemory: false)
    ))
  }

  func restoreTypeState(_ functionContext: FunctionContext, savedVariableName: String) {
    let stateVariable: AST.Expression = .identifier(
      Identifier(name: IRContract.stateVariablePrefix + functionContext.enclosingTypeName,
                 sourceLocation: .DUMMY))
    let selfState: AST.Expression = .binaryExpression(
      BinaryExpression(lhs: .self(Token(kind: .self, sourceLocation: .DUMMY)),
                       op: Token(kind: .punctuation(.dot), sourceLocation: .DUMMY),
                       rhs: stateVariable))
    let stateVariableRendered = IRExpression(expression: selfState, asLValue: true)
      .rendered(functionContext: functionContext)

    functionContext.emit(.expression(
      IRRuntimeFunction.store(address: stateVariableRendered,
                              value: .inline(savedVariableName),
                              inMemory: false)
    ))
  }
}
