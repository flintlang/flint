//
//  IRFunctionSelector.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/28/17.
//

import CryptoSwift
import AST
import Lexer

/// Runtime code in IR which determines which function to call based on the Ethereum's transaction payload.
struct IRFunctionSelector {
  var fallback: SpecialDeclaration?
  var functions: [IRFunction]
  var enclosingType: Identifier
  var environment: Environment

  func rendered() -> String {
    let cases = renderCases()
    let fallback = renderFallback()

    return """
    switch \(IRRuntimeFunction.selector())
    \(cases)
    default {
      \(fallback)
    }
    """
  }

  func renderFallback() -> String {
    if let fallbackDeclaration = fallback {
      return IRContractFallback(fallbackDeclaration: fallbackDeclaration, typeIdentifier: enclosingType, environment: environment).rendered()
    }
    else {
      return "revert(0, 0)"
    }
  }

  func renderCases() -> String {
    return functions.map { function in
      let functionHash = "0x\(function.mangledSignature().sha3(.keccak256).prefix(8))"

      return """

      case \(functionHash) /* \(function.mangledSignature()) */ {
        \(renderCaseBody(function: function).indented(by: 2))
      }

      """
    }.joined()
  }

  func renderCaseBody(function: IRFunction) -> String {
    // Dynamically check that the state is correct for the function to be called.
    let typeStates = function.typeStates
    let typeStateChecks = IRTypeStateChecks(typeStates: typeStates).rendered(enclosingType: enclosingType.name, environment: environment)

    // Dynamically check the caller has appropriate caller capabilities.
    let callerCapabilities = function.callerCapabilities
    let callerCapabilityChecks = IRCallerCapabilityChecks(callerCapabilities: callerCapabilities).rendered(enclosingType: enclosingType.name, environment: environment)

    let arguments = function.parameterCanonicalTypes.enumerated().map { arg -> String in
      let (index, type) = arg
      switch type {
      case .address: return IRRuntimeFunction.decodeAsAddress(offset: index)
      case .uint256, .bytes32: return IRRuntimeFunction.decodeAsUInt(offset: index)
      }
    }
    let wrapperPrefix = function.containsAnyCaller ? "" : "\(IRWrapperFunction.prefixHard)"
    let call =  "\(wrapperPrefix)\(function.name)(\(arguments.joined(separator: ", ")))"

    if let resultType = function.resultCanonicalType {
      switch resultType {
      case .address, .uint256, .bytes32: return typeStateChecks + "\n" + callerCapabilityChecks + "\n" + IRRuntimeFunction.return32Bytes(value: call)
      }
    }

    return "\(typeStateChecks)\n\(callerCapabilityChecks)\n\(call)"
  }
}
