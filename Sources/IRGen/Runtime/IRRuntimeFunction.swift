//
//  IRRuntimeFunction.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/29/17.
//

import AST

/// The runtime functions used by Flint.
enum IRRuntimeFunction {
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

  static func store(address: String, value: String, inMemory: Bool) -> String {
    return "\(inMemory ? "mstore" : "sstore")(\(address), \(value))"
  }

  static func store(address: String, value: String, inMemory: String) -> String {
    return "\(Identifiers.store.mangled)(\(address), \(value), \(inMemory))"
  }

  static func addOffset(base: String, offset: String, inMemory: Bool) -> String {
    return inMemory ? "add(\(base), mul(\(EVM.wordSize), \(offset)))" : "add(\(base), \(offset))"
  }

  static func addOffset(base: String, offset: String, inMemory: String) -> String {
    return "\(Identifiers.computeOffset.mangled)(\(base), \(offset), \(inMemory))"
  }

  static func load(address: String, inMemory: Bool) -> String {
    return "\(inMemory ? "mload" : "sload")(\(address))"
  }

  static func load(address: String, inMemory: String) -> String {
    return "\(Identifiers.load.mangled)(\(address), \(inMemory))"
  }

  static func allocateMemory(size: Int) -> String {
    return "\(Identifiers.allocateMemory.mangled)(\(size))"
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

  static func storageArrayOffset(arrayOffset: String, index: String) -> String {
    return "\(Identifiers.storageArrayOffset.mangled)(\(arrayOffset), \(index))"
  }

  static func storageArraySize(arrayOffset: String) -> String {
    return "\(Identifiers.storageArraySize.mangled)(\(arrayOffset))"
  }

  static func storageFixedSizeArrayOffset(arrayOffset: String, index: String, arraySize: Int) -> String {
    return "\(Identifiers.storageFixedSizeArrayOffset.mangled)(\(arrayOffset), \(index), \(arraySize))"
  }

  static func storageDictionaryOffsetForKey(dictionaryOffset: String, key: String) -> String {
    return "\(Identifiers.storageDictionaryOffsetForKey.mangled)(\(dictionaryOffset), \(key))"
  }

  static func storageDictionaryKeysArrayOffset(dictionaryOffset: String) -> String {
    return "\(Identifiers.storageDictionaryKeysArrayOffset.mangled)(\(dictionaryOffset))"
  }

  static func storageOffsetForKey(baseOffset: String, key: String) -> String {
    return "\(Identifiers.storageOffsetForKey.mangled)(\(baseOffset), \(key))"
  }

  static func callvalue() -> String {
    return "\(Identifiers.callvalue)()"
  }

  static func add(a: String, b: String) -> String {
    return "\(Identifiers.add.mangled)(\(a), \(b))"
  }

  static func sub(a: String, b: String) -> String {
    return "\(Identifiers.sub.mangled)(\(a), \(b))"
  }

  static func mul(a: String, b: String) -> String {
    return "\(Identifiers.mul.mangled)(\(a), \(b))"
  }

  static func div(a: String, b: String) -> String {
    return "\(Identifiers.div.mangled)(\(a), \(b))"
  }

  static func power(b: String, e: String) -> String {
    return "\(Identifiers.power.mangled)(\(b), \(e))"
  }

  static let allDeclarations: [String] = [
    IRRuntimeFunctionDeclaration.selector,
    IRRuntimeFunctionDeclaration.decodeAsAddress,
    IRRuntimeFunctionDeclaration.decodeAsUInt,
    IRRuntimeFunctionDeclaration.store,
    IRRuntimeFunctionDeclaration.load,
    IRRuntimeFunctionDeclaration.computeOffset,
    IRRuntimeFunctionDeclaration.allocateMemory,
    IRRuntimeFunctionDeclaration.checkNoValue,
    IRRuntimeFunctionDeclaration.isMatchingTypeState,
    IRRuntimeFunctionDeclaration.isValidCallerProtection,
    IRRuntimeFunctionDeclaration.isCallerProtectionInArray,
    IRRuntimeFunctionDeclaration.isCallerProtectionInDictionary,
    IRRuntimeFunctionDeclaration.return32Bytes,
    IRRuntimeFunctionDeclaration.isInvalidSubscriptExpression,
    IRRuntimeFunctionDeclaration.storageArrayOffset,
    IRRuntimeFunctionDeclaration.storageFixedSizeArrayOffset,
    IRRuntimeFunctionDeclaration.storageDictionaryOffsetForKey,
    IRRuntimeFunctionDeclaration.storageDictionaryKeysArrayOffset,
    IRRuntimeFunctionDeclaration.storageOffsetForKey,
    IRRuntimeFunctionDeclaration.send,
    IRRuntimeFunctionDeclaration.fatalError,
    IRRuntimeFunctionDeclaration.add,
    IRRuntimeFunctionDeclaration.sub,
    IRRuntimeFunctionDeclaration.mul,
    IRRuntimeFunctionDeclaration.div,
    IRRuntimeFunctionDeclaration.power
  ]
}

struct IRRuntimeFunctionDeclaration {
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
}
