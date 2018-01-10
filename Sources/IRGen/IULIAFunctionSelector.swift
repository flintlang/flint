//
//  IULIAFunctionSelector.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/28/17.
//

import CryptoSwift

struct IULIAFunctionSelector {
  var functions: [IULIAFunction]

  func rendered() -> String {
    let cases = renderCases()

    return """
    switch selector()
    \(cases)
    default {
      revert(0, 0)
    }
    """
  }

  func renderCases() -> String {
    return functions.map { function in
      let functionHash = "0x\(function.mangledSignature().sha3(.keccak256).prefix(8))"

      return """

      case \(functionHash) /* \(function.mangledSignature()) */ {
        \(renderCaseBody(function: function))
      }
      
      """
    }.joined()
  }

  func renderCaseBody(function: IULIAFunction) -> String {
    let arguments = function.parameterCanonicalTypes.enumerated().map { arg -> String in
      let (index, type) = arg
      switch type {
      case .address: return "\(IULIARuntimeFunction.decodeAsAddress.rawValue)(\(index))"
      case .uint256: return "\(IULIARuntimeFunction.decodeAsUInt.rawValue)(\(index))"
      }
    }

    let call = "\(function.name)(\(arguments.joined(separator: ", ")))"

    if let resultType = function.resultCanonicalType {
      switch resultType {
      case .address: fatalError()
      case .uint256: return "\(IULIARuntimeFunction.returnUInt.rawValue)(\(call))"
      }
    }

    return call
  }
}
