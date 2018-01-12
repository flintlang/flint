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
  case returnUInt
  case isInvalidSubscriptExpression
  case storageArrayOffset
  case storageDictionaryOffsetForKey

  var declaration: String {
    switch self {
    case .selector: return IRRuntimeFunctionDeclaration.selector
    case .decodeAsAddress: return IRRuntimeFunctionDeclaration.decodeAsAddress
    case .decodeAsUInt: return IRRuntimeFunctionDeclaration.decodeAsUInt
    case .isValidCallerCapability: return IRRuntimeFunctionDeclaration.isValidCallerCapability
    case .returnUInt: return IRRuntimeFunctionDeclaration.returnUInt
    case .isInvalidSubscriptExpression: return IRRuntimeFunctionDeclaration.isInvalidSubscriptExpression
    case .storageArrayOffset: return IRRuntimeFunctionDeclaration.storageArrayOffset
    case .storageDictionaryOffsetForKey: return IRRuntimeFunctionDeclaration.storageDictionaryOffsetForKey
    }
  }

  static let all: [IULIARuntimeFunction] = [.selector, .decodeAsAddress, .decodeAsUInt, .isValidCallerCapability, .returnUInt, .isInvalidSubscriptExpression, .storageArrayOffset, .storageDictionaryOffsetForKey]
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

  static let returnUInt =
  """
  function returnUInt(v) {
    mstore(0, v)
    return(0, 0x20)
  }
  """

  static let isInvalidSubscriptExpression =
  """
  function isInvalidSubscriptExpression(index, arraySize) -> ret {
    ret := or(lt(index, 0), gt(index, sub(arraySize, 1)))
  }
  """

  static let storageArrayOffset =
  """
  function storageArrayOffset(arrayOffset, index, arraySize) -> ret {
    if isInvalidSubscriptExpression(index, arraySize) { revert(0, 0) }
    ret := add(arrayOffset, index)
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
 
