//
//  UILIAUtilFunction.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/29/17.
//

import Foundation

enum IULIAUtilFunction: String {
  case selector
  case decodeAsAddress
  case decodeAsUInt
  case isValidCallerCapability
  case returnUInt
  case isInvalidArrayAccess
  case storageArrayElementAtIndex
  case storageArrayOffset

  var declaration: String {
    switch self {
    case .selector: return IRUtilFunctionDeclaration.selector
    case .decodeAsAddress: return IRUtilFunctionDeclaration.decodeAsAddress
    case .decodeAsUInt: return IRUtilFunctionDeclaration.decodeAsUInt
    case .isValidCallerCapability: return IRUtilFunctionDeclaration.isValidCallerCapability
    case .returnUInt: return IRUtilFunctionDeclaration.returnUInt
    case .isInvalidArrayAccess: return IRUtilFunctionDeclaration.isInvalidArrayAccess
    case .storageArrayElementAtIndex: return IRUtilFunctionDeclaration.storageArrayElementAtIndex
    case .storageArrayOffset: return IRUtilFunctionDeclaration.storageArrayOffset
    }
  }

  static let all: [IULIAUtilFunction] = [.selector, .decodeAsAddress, .decodeAsUInt, .isValidCallerCapability, .returnUInt, .isInvalidArrayAccess, .storageArrayElementAtIndex, .storageArrayOffset]
}

fileprivate struct IRUtilFunctionDeclaration {
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

  static let isInvalidArrayAccess =
  """
  function isInvalidArrayAccess(index, arraySize) -> ret {
    ret := or(lt(index, 0), gt(index, sub(arraySize, 1)))
  }
  """

  static let storageArrayElementAtIndex =
  """
  function storageArrayElementAtIndex(arrayOffset, index, arraySize) -> ret {
    if isInvalidArrayAccess(index, arraySize) { revert(0, 0) }
    ret := sload(add(arrayOffset, index))
  }
  """

  static let storageArrayOffset =
  """
  function storageArrayOffset(arrayOffset, index, arraySize) -> ret {
    if isInvalidArrayAccess(index, arraySize) { revert(0, 0) }
    ret := add(arrayOffset, index)
  }
  """
}
