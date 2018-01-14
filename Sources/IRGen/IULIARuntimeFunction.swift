//
//  IULIARuntimeFunction.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/29/17.
//

import Foundation

enum IULIARuntimeFunction: String {
  case selector
  case decodeAsAddress
  case decodeAsUInt
  case isValidCallerCapability
  case isCallerCapabilityInArray
  case return32Bytes
  case isInvalidSubscriptExpression
  case storageArrayOffset
  case storageFixedSizeArrayOffset
  case storageDictionaryOffsetForKey

  var declaration: String {
    switch self {
    case .selector: return IRRuntimeFunctionDeclaration.selector
    case .decodeAsAddress: return IRRuntimeFunctionDeclaration.decodeAsAddress
    case .decodeAsUInt: return IRRuntimeFunctionDeclaration.decodeAsUInt
    case .isValidCallerCapability: return IRRuntimeFunctionDeclaration.isValidCallerCapability
    case .return32Bytes: return IRRuntimeFunctionDeclaration.return32Bytes
    case .isInvalidSubscriptExpression: return IRRuntimeFunctionDeclaration.isInvalidSubscriptExpression
    case .storageArrayOffset: return IRRuntimeFunctionDeclaration.storageArrayOffset
    case .isCallerCapabilityInArray: return IRRuntimeFunctionDeclaration.isCallerCapabilityInArray
    case .storageFixedSizeArrayOffset: return IRRuntimeFunctionDeclaration.storageFixedSizeArrayOffset
    case .storageDictionaryOffsetForKey: return IRRuntimeFunctionDeclaration.storageDictionaryOffsetForKey
    }
  }

  static let all: [IULIARuntimeFunction] = [.selector, .decodeAsAddress, .decodeAsUInt, .isValidCallerCapability, .isCallerCapabilityInArray, .return32Bytes, .isInvalidSubscriptExpression, .storageArrayOffset, .storageFixedSizeArrayOffset, .storageDictionaryOffsetForKey]
}

fileprivate struct IRRuntimeFunctionDeclaration {
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
 
