//
//  IULIAFunctionSelector.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/28/17.
//

import CryptoSwift
import AST

/// Runtime code in IULIA which determines which function to call based on the Ethereum's transaction payload.
struct IULIAFunctionSelector {
  var fallback: SpecialDeclaration?
  var functions: [IULIAFunction]
  var enclosingType: Identifier
  var environment: Environment

  func rendered() -> String {
    let cases = renderCases()
    let fallback = renderFallback()

    return """
    switch \(IULIARuntimeFunction.selector())
    \(cases)
    default {
      \(fallback)
    }
    """
  }

  func renderFallback() -> String {
    if let fallbackDeclaration = fallback {
      return IULIAContractFallback(fallbackDeclaration: fallbackDeclaration, typeIdentifier: enclosingType, environment: environment).rendered()
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

  func renderCaseBody(function: IULIAFunction) -> String {
    // Dynamically check the caller has appropriate caller capabilities.
    let callerCapabilities = function.callerCapabilities
    let callerCapabilityChecks = IULIACallerCapabilityChecks(callerCapabilities: callerCapabilities).rendered(enclosingType: enclosingType.name, environment: environment)

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
      case .address, .uint256, .bytes32: return callerCapabilityChecks + "\n" + IULIARuntimeFunction.return32Bytes(value: call)
      }
    }

    return callerCapabilityChecks + "\n" + call
  }
}

/// Checks whether the caller of a function has appropriate caller capabilities.
struct IULIACallerCapabilityChecks {
  var callerCapabilities: [CallerCapability]

  func rendered(enclosingType: RawTypeIdentifier, environment: Environment) -> String {
    let checks = callerCapabilities.compactMap { callerCapability -> String? in
      guard !callerCapability.isAny else { return nil }

      let type = environment.type(of: callerCapability.identifier.name, enclosingType: enclosingType)
      let offset = environment.propertyOffset(for: callerCapability.name, enclosingType: enclosingType)!

      switch type {
      case .fixedSizeArrayType(_, let size):
        return (0..<size).map { index in
          let check = IULIARuntimeFunction.isValidCallerCapability(address: "sload(add(\(offset), \(index)))")
          return "_flintCallerCheck := add(_flintCallerCheck, \(check)"
          }.joined(separator: "\n")
      case .arrayType(_):
        let check = IULIARuntimeFunction.isCallerCapabilityInArray(arrayOffset: offset)
        return "_flintCallerCheck := add(_flintCallerCheck, \(check))"
      default:
        let check = IULIARuntimeFunction.isValidCallerCapability(address: "sload(\(offset)))")
        return "_flintCallerCheck := add(_flintCallerCheck, \(check)"
      }
    }

    if !checks.isEmpty {
      return """
        let _flintCallerCheck := 0
        \(checks.joined(separator: "\n"))
        if eq(_flintCallerCheck, 0) { revert(0, 0) }
        """ + "\n"
    }

    return ""
  }
}

