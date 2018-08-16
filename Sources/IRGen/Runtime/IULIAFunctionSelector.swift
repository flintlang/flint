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
    // Dynamically check that the state is correct for the function to be called.
    let typeStates = function.typeStates
    let typeStateChecks = IULIATypeStateChecks(typeStates: typeStates).rendered(enclosingType: enclosingType.name, environment: environment)

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
      case .address, .uint256, .bytes32: return typeStateChecks + "\n" + callerCapabilityChecks + "\n" + IULIARuntimeFunction.return32Bytes(value: call)
      }
    }

    return "\(typeStateChecks)\n\(callerCapabilityChecks)\n\(call)"
  }
}

/// Checks if the state is correct for a function to be called.
struct IULIATypeStateChecks {
  var typeStates: [TypeState]

  func rendered(enclosingType: RawTypeIdentifier, environment: Environment) -> String {
    let checks = typeStates.compactMap { typeState -> String? in
      guard !typeState.isAny else { return nil }

      let stateValue = IULIAExpression(expression: environment.getStateValue(typeState.identifier, in: enclosingType), asLValue: false).rendered(functionContext: FunctionContext(environment: environment, scopeContext: ScopeContext(), enclosingTypeName: enclosingType, isInStructFunction: false))

      let dummySourceLocation = SourceLocation(line: 0, column: 0, length: 0, file: .init(fileURLWithPath: ""))
      let stateVariable: Expression = .identifier(Identifier(name: IULIAContract.stateVariablePrefix + enclosingType))
      let selfState: Expression = .binaryExpression(BinaryExpression(lhs: .self(Token(kind: .self, sourceLocation: dummySourceLocation)), op: Token(kind: .punctuation(.dot), sourceLocation: dummySourceLocation), rhs: stateVariable))
      let stateVariableRendered = IULIAExpression(expression: selfState, asLValue: false).rendered(functionContext: FunctionContext(environment: environment, scopeContext: ScopeContext(), enclosingTypeName: enclosingType, isInStructFunction: false))

      let check = IULIARuntimeFunction.isMatchingTypeState(stateValue, stateVariableRendered)
      return "_flintStateCheck := add(_flintStateCheck, \(check))"
    }

    if !checks.isEmpty {
      return """
      let _flintStateCheck := 0
      \(checks.joined(separator: "\n"))
      if eq(_flintStateCheck, 0) { revert(0, 0) }
      """ + "\n"
    }

    return ""
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
      case .dictionaryType(_, _):
        let check = IULIARuntimeFunction.isCallerCapabilityInDictionary(dictionaryOffset: offset)
        return "_flintCallerCheck := add(_flintCallerCheck, \(check))"
      default:
        let check = IULIARuntimeFunction.isValidCallerCapability(address: "sload(\(offset))")
        return "_flintCallerCheck := add(_flintCallerCheck, \(check))"
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
