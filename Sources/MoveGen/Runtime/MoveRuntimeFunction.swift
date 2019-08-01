//
//  MoveRuntimeFunction.swift
//  MoveGen
//
//  Created on 30/Jul/2019.
//

import AST
import MoveIR

/// The runtime functions used by Flint.
enum MoveRuntimeFunction {
  enum Identifiers {
    case selector
    case decodeAsAddress
    case decodeAsUInt
    case store
    case load
    case computeOffset
    case allocateMemory
    case checkNoValue
    case isMatchingTypeState
    case isValidCallerProtection
    case isCallerProtectionInArray
    case isCallerProtectionInDictionary
    case return32Bytes
    case isInvalidSubscriptExpression
    case storageArrayOffset
    case storageArraySize
    case storageFixedSizeArrayOffset
    case storageDictionaryOffsetForKey
    case storageDictionaryKeysArrayOffset
    case storageOffsetForKey
    case callvalue
    case send
    case fatalError
    case add
    case sub
    case mul
    case div
    case power
    case revertIfGreater

    var mangled: String {
      return "\(Environment.runtimeFunctionPrefix)\(self)"
    }
  }

  static func fatalError() -> String {
    return "\(Identifiers.fatalError.mangled)()"
  }

  static func selector() -> String {
    return "\(Identifiers.selector.mangled)()"
  }

  static func decodeAsAddress(offset: Int) -> String {
    return "\(Identifiers.decodeAsAddress.mangled)(\(offset))"
  }

  static func decodeAsUInt(offset: Int) -> String {
    return "\(Identifiers.decodeAsUInt.mangled)(\(offset))"
  }

  static func store(address: MoveIR.Expression, value: MoveIR.Expression, inMemory: Bool) -> MoveIR.Expression {
    print("WARNING: Manual memory/stack store call generated for `\(value)` [MoveRuntimeFunction.swift:67]")
    return .functionCall(FunctionCall(inMemory ? "mstore" : "sstore", address, value))
  }

  static func store(address: MoveIR.Expression, value: MoveIR.Expression, inMemory: String) -> MoveIR.Expression {
    print("WARNING: Manual named memory/stack store call generated for `\(value)` [MoveRuntimeFunction.swift:72]")
    return .functionCall(FunctionCall(Identifiers.store.mangled, address, value, .identifier(inMemory)))
  }

  static func addOffset(base: MoveIR.Expression, offset: MoveIR.Expression, inMemory: Bool) -> MoveIR.Expression {
    print("WARNING: Address offset call generated for `\(base)`, `\(offset)` [MoveRuntimeFunction.swift:77]")
    return .functionCall(FunctionCall("add", base,
      inMemory ? .functionCall(FunctionCall("mul", .literal(.num(EVM.wordSize)), offset)) : offset))
  }

  static func addOffset(base: MoveIR.Expression, offset: MoveIR.Expression, inMemory: String) -> MoveIR.Expression {
    print("WARNING: Address offset call generated for `\(base)`, `\(offset)` [MoveRuntimeFunction.swift:83]")
    return .functionCall(FunctionCall(Identifiers.computeOffset.mangled, base, offset, .identifier(inMemory)))
  }

  static func load(address: MoveIR.Expression, inMemory: Bool) -> MoveIR.Expression {
    print("WARNING: Manual memory/stack load call generated for `\(address)` [MoveRuntimeFunction.swift:88]")
    return .functionCall(FunctionCall(inMemory ? "mload" : "sload", address))
  }

  static func load(address: MoveIR.Expression, inMemory: String) -> MoveIR.Expression {
    print("WARNING: Manual named memory/stack load call generated for `\(address)` [MoveRuntimeFunction.swift:93]")
    return .functionCall(FunctionCall(Identifiers.load.mangled, address, .identifier(inMemory)))
  }

  static func allocateMemory(size: Int) -> MoveIR.Expression {
    print("WARNING: Manual memory allocation call generated of size `\(size)` [MoveRuntimeFunction.swift:98]")
    return .functionCall(FunctionCall(Identifiers.allocateMemory.mangled, .literal(.num(size))))
  }

  static func checkNoValue(_ value: String) -> String {
    return "\(Identifiers.checkNoValue.mangled)(\(value))"
  }

  static func isMatchingTypeState(_ stateValue: String, _ stateVariable: String) -> String {
    return "\(Identifiers.isMatchingTypeState.mangled)(\(stateValue), \(stateVariable))"
  }

  static func isValidCallerProtection(address: String) -> String {
    return "\(Identifiers.isValidCallerProtection.mangled)(\(address))"
  }

  static func isCallerProtectionInArray(arrayOffset: Int) -> String {
    return "\(Identifiers.isCallerProtectionInArray.mangled)(\(arrayOffset))"
  }

  static func isCallerProtectionInDictionary(dictionaryOffset: Int) -> String {
    return "\(Identifiers.isCallerProtectionInDictionary.mangled)(\(dictionaryOffset))"
  }

  static func return32Bytes(value: String) -> String {
    return "\(Identifiers.return32Bytes.mangled)(\(value))"
  }

  static func isInvalidSubscriptExpression(index: Int, arraySize: Int) -> String {
    return "\(Identifiers.isInvalidSubscriptExpression.mangled)(\(index), \(arraySize))"
  }

  static func storageArrayOffset(arrayOffset: MoveIR.Expression, index: MoveIR.Expression) -> MoveIR.Expression {
    return .functionCall(FunctionCall(Identifiers.storageArrayOffset.mangled, arrayOffset, index))
  }

  static func storageArraySize(arrayOffset: String) -> String {
    return "\(Identifiers.storageArraySize.mangled)(\(arrayOffset))"
  }

  static func storageFixedSizeArrayOffset(arrayOffset: MoveIR.Expression,
                                          index: MoveIR.Expression, arraySize: Int) -> MoveIR.Expression {
    return .functionCall(FunctionCall(Identifiers.storageFixedSizeArrayOffset.mangled,
                                      arrayOffset, index, .literal(.num(arraySize))))
  }

  static func storageDictionaryOffsetForKey(dictionaryOffset: MoveIR.Expression,
                                            key: MoveIR.Expression) -> MoveIR.Expression {
    return .functionCall(FunctionCall(Identifiers.storageDictionaryOffsetForKey.mangled, dictionaryOffset, key))
  }

  static func storageDictionaryKeysArrayOffset(dictionaryOffset: MoveIR.Expression) -> MoveIR.Expression {
    return .functionCall(FunctionCall(Identifiers.storageDictionaryKeysArrayOffset.mangled, dictionaryOffset))
  }

  static func storageOffsetForKey(baseOffset: MoveIR.Expression, key: MoveIR.Expression) -> MoveIR.Expression {
    return .functionCall(FunctionCall(Identifiers.storageOffsetForKey.mangled, baseOffset, key))
  }

  static func callvalue() -> String {
    return "\(Identifiers.callvalue)()"
  }

  static func add(a: MoveIR.Expression, b: MoveIR.Expression) -> MoveIR.Expression {
    return .functionCall(FunctionCall(Identifiers.add.mangled, a, b))
  }

  static func sub(a: MoveIR.Expression, b: MoveIR.Expression) -> MoveIR.Expression {
    return .functionCall(FunctionCall(Identifiers.sub.mangled, a, b))
  }

  static func mul(a: MoveIR.Expression, b: MoveIR.Expression) -> MoveIR.Expression {
    return .functionCall(FunctionCall(Identifiers.mul.mangled, a, b))
  }

  static func div(a: MoveIR.Expression, b: MoveIR.Expression) -> MoveIR.Expression {
    return .functionCall(FunctionCall(Identifiers.div.mangled, a, b))
  }

  static func power(b: MoveIR.Expression, e: MoveIR.Expression) -> MoveIR.Expression {
    return .functionCall(FunctionCall(Identifiers.power.mangled, b, e))
  }

  static func revertIfGreater(value: MoveIR.Expression, max: MoveIR.Expression) -> MoveIR.Expression {
    return .functionCall(FunctionCall(Identifiers.revertIfGreater.mangled, value, max))
  }

  static let allDeclarations: [String] = [
    MoveRuntimeFunctionDeclaration.selector,
    MoveRuntimeFunctionDeclaration.decodeAsAddress,
    MoveRuntimeFunctionDeclaration.decodeAsUInt,
    MoveRuntimeFunctionDeclaration.store,
    MoveRuntimeFunctionDeclaration.load,
    MoveRuntimeFunctionDeclaration.computeOffset,
    MoveRuntimeFunctionDeclaration.allocateMemory,
    MoveRuntimeFunctionDeclaration.checkNoValue,
    MoveRuntimeFunctionDeclaration.isMatchingTypeState,
    MoveRuntimeFunctionDeclaration.isValidCallerProtection,
    MoveRuntimeFunctionDeclaration.isCallerProtectionInArray,
    MoveRuntimeFunctionDeclaration.isCallerProtectionInDictionary,
    MoveRuntimeFunctionDeclaration.return32Bytes,
    MoveRuntimeFunctionDeclaration.isInvalidSubscriptExpression,
    MoveRuntimeFunctionDeclaration.storageArrayOffset,
    MoveRuntimeFunctionDeclaration.storageFixedSizeArrayOffset,
    MoveRuntimeFunctionDeclaration.storageDictionaryOffsetForKey,
    MoveRuntimeFunctionDeclaration.storageDictionaryKeysArrayOffset,
    MoveRuntimeFunctionDeclaration.storageOffsetForKey,
    MoveRuntimeFunctionDeclaration.send,
    MoveRuntimeFunctionDeclaration.fatalError,
    MoveRuntimeFunctionDeclaration.add,
    MoveRuntimeFunctionDeclaration.sub,
    MoveRuntimeFunctionDeclaration.mul,
    MoveRuntimeFunctionDeclaration.div,
    MoveRuntimeFunctionDeclaration.power,
    MoveRuntimeFunctionDeclaration.revertIfGreater
  ]
}

struct MoveRuntimeFunctionDeclaration {
  static let selector =
  """
  function flint$selector() -> ret {
    ret := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
  }
  """

  static let decodeAsAddress =
  """
  function flint$decodeAsAddress(offset) -> ret {
    ret := flint$decodeAsUInt(offset)
  }
  """

  static let decodeAsUInt =
  """
  function flint$decodeAsUInt(offset) -> ret {
    ret := calldataload(add(4, mul(offset, 0x20)))
  }
  """

  static let store =
  """
  function flint$store(ptr, val, mem) {
    switch iszero(mem)
    case 0 {
      mstore(ptr, val)
    }
    default {
      sstore(ptr, val)
    }
  }
  """

  static let load =
  """
  function flint$load(ptr, mem) -> ret {
    switch iszero(mem)
    case 0 {
      ret := mload(ptr)
    }
    default {
      ret := sload(ptr)
    }
  }
  """

  static let computeOffset =
  """
  function flint$computeOffset(base, offset, mem) -> ret {
    switch iszero(mem)
    case 0 {
      ret := add(base, mul(offset, \(EVM.wordSize)))
    }
    default {
      ret := add(base, offset)
    }
  }
  """

  static let allocateMemory =
  """
  function flint$allocateMemory(size) -> ret {
    ret := mload(0x40)
    mstore(0x40, add(ret, size))
  }
  """

  static let checkNoValue =
  """
  function flint$checkNoValue(_value) {
    if iszero(iszero(_value)) {
      flint$fatalError()
    }
  }
  """

  static let isMatchingTypeState =
  """
  function flint$isMatchingTypeState(_state, _stateVariable) -> ret {
    ret := eq(_stateVariable, _state)
  }
  """

  static let isValidCallerProtection =
  """
  function flint$isValidCallerProtection(_address) -> ret {
    ret := eq(_address, caller())
  }
  """

  static let isCallerProtectionInArray =
  """
  function flint$isCallerProtectionInArray(arrayOffset) -> ret {
    let size := sload(arrayOffset)
    let found := 0
    let _caller := caller()
    for { let i := 0 } and(lt(i, size), iszero(found)) { i := add(i, 1) } {
      if eq(sload(flint$storageOffsetForKey(arrayOffset, i)), _caller) {
        found := 1
      }
    }
    ret := found
  }
  """

  static let isCallerProtectionInDictionary =
  """
  function flint$isCallerProtectionInDictionary(dictionaryOffset) -> ret {
    let size := sload(dictionaryOffset)
    let arrayOffset := flint$storageDictionaryKeysArrayOffset(dictionaryOffset)
    let found := 0
    let _caller := caller()
    for { let i := 0 } and(lt(i, size), iszero(found)) { i := add(i, i) } {
      let key := sload(flint$storageOffsetForKey(arrayOffset, i))
      if eq(sload(flint$storageOffsetForKey(dictionaryOffset, key)), _caller) {
        found := 1
      }
    }
    ret := found
  }
  """

  static let return32Bytes =
  """
  function flint$return32Bytes(v) {
    mstore(0, v)
    return(0, 0x20)
  }
  """

  static let isInvalidSubscriptExpression =
  """
  function flint$isInvalidSubscriptExpression(index, arraySize) -> ret {
    ret := or(iszero(arraySize), or(lt(index, 0), gt(index, flint$sub(arraySize, 1))))
  }
  """

  static let storageFixedSizeArrayOffset =
  """
  function flint$storageFixedSizeArrayOffset(arrayOffset, index, arraySize) -> ret {
    if flint$isInvalidSubscriptExpression(index, arraySize) { revert(0, 0) }
    ret := flint$add(arrayOffset, index)
  }
  """

  static let storageArrayOffset =
  """
  function flint$storageArrayOffset(arrayOffset, index) -> ret {
    let arraySize := sload(arrayOffset)

    switch eq(arraySize, index)
    case 0 {
      if flint$isInvalidSubscriptExpression(index, arraySize) { revert(0, 0) }
    }
    default {
      sstore(arrayOffset, flint$add(arraySize, 1))
    }

    ret := flint$storageOffsetForKey(arrayOffset, index)
  }
  """

  static let storageDictionaryOffsetForKey =
  """
  function flint$storageDictionaryOffsetForKey(dictionaryOffset, key) -> ret {
    let offsetForKey := flint$storageOffsetForKey(dictionaryOffset, key)
    mstore(0, offsetForKey)
    let indexOffset := sha3(0, 32)
    switch eq(sload(indexOffset), 0)
    case 1 {
      let keysArrayOffset := flint$storageDictionaryKeysArrayOffset(dictionaryOffset)
      let index := add(sload(dictionaryOffset), 1)
      sstore(indexOffset, index)
      sstore(flint$storageOffsetForKey(keysArrayOffset, index), key)
      sstore(dictionaryOffset, index)
    }
    ret := offsetForKey
  }
  """

  static let storageOffsetForKey =
  """
  function flint$storageOffsetForKey(offset, key) -> ret {
    mstore(0, key)
    mstore(32, offset)
    ret := sha3(0, 64)
  }
  """

  static let storageDictionaryKeysArrayOffset =
  """
  function flint$storageDictionaryKeysArrayOffset(dictionaryOffset) -> ret {
    mstore(0, dictionaryOffset)
    ret := sha3(0, 32)
  }
  """

  static let send =
  """
  function flint$send(_value, _address) {
    let ret := call(gas(), _address, _value, 0, 0, 0, 0)

    if iszero(ret) {
      revert(0, 0)
    }
  }
  """

  static let fatalError =
  """
  function flint$fatalError() {
    revert(0, 0)
  }
  """

  static let add =
  """
  function flint$add(a, b) -> ret {
    let c := add(a, b)

    if lt(c, a) { revert(0, 0) }
    ret := c
  }
  """

  static let sub =
  """
  function flint$sub(a, b) -> ret {
    if gt(b, a) { revert(0, 0) }

    ret := sub(a, b)
  }
  """

  static let mul =
  """
  function flint$mul(a, b) -> ret {
    switch iszero(a)
    case 1 {
      ret := 0
    }
    default {
      let c := mul(a, b)
      if iszero(eq(div(c, a), b)) { revert(0, 0) }
      ret := c
    }
  }
  """

  static let div =
  """
  function flint$div(a, b) -> ret {
    if eq(b, 0) { revert(0, 0) }
    ret := div(a, b)
  }
  """

  static let power =
  """
  function flint$power(b, e) -> ret {
    ret := 1
    for { let i := 0 } lt(i, e) { i := add(i, 1) }
    {
        ret := flint$mul(ret, b)
    }
  }
  """

  // Ensure that a <= b
  static let revertIfGreater =
  """
  flint$revertIfGreater(a, b) -> u64 {
    if (a > b) { revert(0, 0); }
    return a;
  }
  """
}
