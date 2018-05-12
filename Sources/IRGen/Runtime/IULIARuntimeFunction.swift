//
//  IULIARuntimeFunction.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/29/17.
//

import AST

/// The runtime functions used by Flint.
enum IULIARuntimeFunction {
  enum Identifiers: String {
    case selector
    case decodeAsAddress
    case decodeAsUInt
    case store
    case load
    case computeOffset
    case allocateMemory
    case isValidCallerCapability
    case isCallerCapabilityInArray
    case return32Bytes
    case isInvalidSubscriptExpression
    case storageArrayOffset
    case storageFixedSizeArrayOffset
    case storageDictionaryOffsetForKey
    case callvalue
  }

  static func selector() -> String {
    return "\(Identifiers.selector)()"
  }

  static func decodeAsAddress(offset: Int) -> String {
    return "\(Identifiers.decodeAsAddress)(\(offset))"
  }

  static func decodeAsUInt(offset: Int) -> String {
    return "\(Identifiers.decodeAsUInt)(\(offset))"
  }

  static func store(address: String, value: String, inMemory: Bool) -> String {
    return "\(inMemory ? "mstore" : "sstore")(\(address), \(value))"
  }

  static func store(address: String, value: String, inMemory: String) -> String {
    return "\(Identifiers.store)(\(address), \(value), \(inMemory))"
  }

  static func addOffset(base: String, offset: String, inMemory: Bool) -> String {
    return inMemory ? "add(\(base), mul(\(EVM.wordSize), \(offset)))" : "add(\(base), \(offset))"
  }

  static func addOffset(base: String, offset: String, inMemory: String) -> String {
    return "\(Identifiers.computeOffset)(\(base), \(offset), \(inMemory))"
  }

  static func load(address: String, inMemory: Bool) -> String {
    return "\(inMemory ? "mload" : "sload")(\(address))"
  }

  static func load(address: String, inMemory: String) -> String {
    return "\(Identifiers.load)(\(address), \(inMemory))"
  }

  static func allocateMemory(size: Int) -> String {
    return "\(Identifiers.allocateMemory)(\(size))"
  }

  static func isValidCallerCapability(address: String) -> String {
    return "\(Identifiers.isValidCallerCapability)(\(address))"
  }

  static func isCallerCapabilityInArray(arrayOffset: Int) -> String {
    return "\(Identifiers.isCallerCapabilityInArray)(\(arrayOffset))"
  }

  static func return32Bytes(value: String) -> String {
    return "\(Identifiers.return32Bytes)(\(value))"
  }

  static func isInvalidSubscriptExpression(index: Int, arraySize: Int) -> String {
    return "\(Identifiers.isInvalidSubscriptExpression)(\(index), \(arraySize))"
  }

  static func storageFixedSizeArrayOffset(arrayOffset: Int, index: String, arraySize: Int) -> String {
    return "\(Identifiers.storageFixedSizeArrayOffset)(\(arrayOffset), \(index), \(arraySize))"
  }

  static func storageArrayOffset(arrayOffset: Int, index: String) -> String {
    return "\(Identifiers.storageArrayOffset)(\(arrayOffset), \(index))"
  }

  static func storageDictionaryOffsetForKey(dictionaryOffset: Int, key: String) -> String {
    return "\(Identifiers.storageDictionaryOffsetForKey)(\(dictionaryOffset), \(key))"
  }

  static func callvalue() -> String {
    return "\(Identifiers.callvalue)()"
  }

  static let allDeclarations: [String] = [IULIARuntimeFunctionDeclaration.selector, IULIARuntimeFunctionDeclaration.decodeAsAddress, IULIARuntimeFunctionDeclaration.decodeAsUInt, IULIARuntimeFunctionDeclaration.store, IULIARuntimeFunctionDeclaration.load, IULIARuntimeFunctionDeclaration.computeOffset, IULIARuntimeFunctionDeclaration.allocateMemory, IULIARuntimeFunctionDeclaration.isValidCallerCapability, IULIARuntimeFunctionDeclaration.isCallerCapabilityInArray, IULIARuntimeFunctionDeclaration.return32Bytes, IULIARuntimeFunctionDeclaration.isInvalidSubscriptExpression, IULIARuntimeFunctionDeclaration.storageArrayOffset, IULIARuntimeFunctionDeclaration.storageFixedSizeArrayOffset, IULIARuntimeFunctionDeclaration.storageDictionaryOffsetForKey]

}

struct IULIARuntimeFunctionDeclaration {
  static let selector =
  """
  function selector() -> ret {
    ret := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
  }
  """

  static let decodeAsAddress =
  """
  function decodeAsAddress(offset) -> ret {
    ret := decodeAsUInt(offset)
  }
  """

  static let decodeAsUInt =
  """
  function decodeAsUInt(offset) -> ret {
    ret := calldataload(add(4, mul(offset, 0x20)))
  }
  """

  static let store =
  """
  function store(ptr, val, mem) {
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
  function load(ptr, mem) -> ret {
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
  function computeOffset(base, offset, mem) -> ret {
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
  function allocateMemory(size) -> ret {
    ret := mload(0x40)
    mstore(0x40, add(ret, size))
  }
  """

  static let isValidCallerCapability =
  """
  function isValidCallerCapability(_address) -> ret {
    ret := eq(_address, caller())
  }
  """

  static let isCallerCapabilityInArray =
  """
  function isCallerCapabilityInArray(arrayOffset) -> ret {
    let size := sload(arrayOffset)
    let found := 0
    let _caller := caller()
    let arrayStart := add(arrayOffset, 1)
    for { let i := 0 } and(lt(i, size), iszero(found)) { i := add(i, 1) } {
      if eq(sload(storageArrayOffset(arrayOffset, i)), _caller) {
        found := 1
      }
    }
    ret := found
  }
  """

  static let return32Bytes =
  """
  function return32Bytes(v) {
    mstore(0, v)
    return(0, 0x20)
  }
  """

  static let isInvalidSubscriptExpression =
  """
  function isInvalidSubscriptExpression(index, arraySize) -> ret {
    ret := or(iszero(arraySize), or(lt(index, 0), gt(index, sub(arraySize, 1))))
  }
  """

  static let storageFixedSizeArrayOffset =
  """
  function storageFixedSizeArrayOffset(arrayOffset, index, arraySize) -> ret {
    if isInvalidSubscriptExpression(index, arraySize) { revert(0, 0) }
    ret := add(arrayOffset, index)
  }
  """

  static let storageArrayOffset =
  """
  function storageArrayOffset(arrayOffset, index) -> ret {
    let arraySize := sload(arrayOffset)

    switch eq(arraySize, index)
    case 0 {
      if isInvalidSubscriptExpression(index, arraySize) { revert(0, 0) }
    }
    default {
      sstore(arrayOffset, add(arraySize, 1))
    }

    ret := storageDictionaryOffsetForKey(arrayOffset, index)
  }
  """

  static let storageDictionaryOffsetForKey =
  """
  function storageDictionaryOffsetForKey(dictionaryOffset, key) -> ret {
    mstore(0, key)
    mstore(32, dictionaryOffset)
    ret := sha3(0, 64)
  }
  """
}
 
