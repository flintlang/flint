//
//  UILIAUtilFunction.swift
//  IULIABackend
//
//  Created by Franklin Schrans on 12/29/17.
//

import Foundation

enum IULIAUtilFunction: String {
  case selector
  case decodeAsAddress
  case decodeAsUInt
  case calledBy
  case returnUInt

  var declaration: String {
    switch self {
    case .selector: return IULIAUtilFunctionDeclaration.selector
    case .decodeAsAddress: return IULIAUtilFunctionDeclaration.decodeAsAddress
    case .decodeAsUInt: return IULIAUtilFunctionDeclaration.decodeAsUInt
    case .calledBy: return IULIAUtilFunctionDeclaration.calledBy
    case .returnUInt: return IULIAUtilFunctionDeclaration.returnUInt
    }
  }

  static let all: [IULIAUtilFunction] = [.selector, .decodeAsAddress, .decodeAsUInt, .calledBy, .returnUInt]
}

fileprivate struct IULIAUtilFunctionDeclaration {
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

  static let calledBy =
  """
  function calledBy(_address) -> ret {
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
}
