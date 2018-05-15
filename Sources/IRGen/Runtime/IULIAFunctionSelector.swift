//
//  IULIAFunctionSelector.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/28/17.
//

import CryptoSwift

/// Runtime code in IULIA which determines which function to call based on the Ethereum's transaction payload.
struct IULIAFunctionSelector {
  var functions: [IULIAFunction]

  func rendered() -> String {
    let cases = renderCases()

    return """
    switch \(IULIARuntimeFunction.selector())
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
      case .address: return IULIARuntimeFunction.decodeAsAddress(offset: index)
      case .uint256, .bytes32: return IULIARuntimeFunction.decodeAsUInt(offset: index)
      }
    }

    let call = "\(function.name)(\(arguments.joined(separator: ", ")))"

    if let resultType = function.resultCanonicalType {
      switch resultType {
      case .address, .uint256, .bytes32: return IULIARuntimeFunction.return32Bytes(value: call)
      }
    }

    return call
  }
}
