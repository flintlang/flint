//
//  IULIARuntimeFunction.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/29/17.
//

import Foundation

/// The runtime functions used by Flint.
enum IULIARuntimeFunction {
  enum Identifiers: String {
    case selector
    case decodeAsAddress
    case decodeAsUInt
    case store
    case allocateMemory
    case isValidCallerCapability
    case isCallerCapabilityInArray
    case return32Bytes
    case isInvalidSubscriptExpression
    case storageArrayOffset
    case storageFixedSizeArrayOffset
    case storageDictionaryOffsetForKey
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
    return "\(Identifiers.store)(\(address), \(value), \(inMemory ? 1 : 0))"
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

  static let allDeclarations: [String] = [IRRuntimeFunctionDeclaration.selector, IRRuntimeFunctionDeclaration.decodeAsAddress, IRRuntimeFunctionDeclaration.decodeAsUInt, IRRuntimeFunctionDeclaration.store, IRRuntimeFunctionDeclaration.allocateMemory, IRRuntimeFunctionDeclaration.isValidCallerCapability, IRRuntimeFunctionDeclaration.isCallerCapabilityInArray, IRRuntimeFunctionDeclaration.return32Bytes, IRRuntimeFunctionDeclaration.isInvalidSubscriptExpression, IRRuntimeFunctionDeclaration.storageArrayOffset, IRRuntimeFunctionDeclaration.storageFixedSizeArrayOffset, IRRuntimeFunctionDeclaration.storageDictionaryOffsetForKey]

}

struct IRRuntimeFunctionDeclaration {
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
 
