//
//  IRFunctionSelector.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/28/17.
//

import AST
import Lexer
import ABI
import YUL

/// Runtime code in IR which determines which function to call based on the Ethereum's transaction payload.
struct IRFunctionSelector {
  var fallback: SpecialDeclaration?
  var functions: [IRFunction]
  var enclosingType: AST.Identifier
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
      return IRContractFallback(fallbackDeclaration: fallbackDeclaration,
                                typeIdentifier: enclosingType,
                                environment: environment).rendered()
    } else {
      return "revert(0, 0)"
    }
  }

  func renderCases() -> String {
    return functions.map { function in
      let functionHash = ABI.soliditySelectorHex(of: function.mangledSignature())

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
    let typeStateChecks = IRTypeStateChecks(typeStates: typeStates)
        .rendered(enclosingType: enclosingType.name, environment: environment)

    // Dynamically check the caller has appropriate caller protections.
    let callerProtections = function.callerProtections
    let callerProtectionChecks = IRCallerProtectionChecks(callerProtections: callerProtections)
        .rendered(enclosingType: enclosingType.name, environment: environment)

    // Dynamically check the function is not being called with value, if it is not payable.
    let valueChecks: String
    if !function.functionDeclaration.isPayable {
      valueChecks = IRRuntimeFunction.checkNoValue(IRRuntimeFunction.callvalue()) + "\n"
    } else {
      valueChecks = ""
    }

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
      case .address, .uint256, .bytes32:
        return typeStateChecks.description + "\n" + callerProtectionChecks + "\n" +
          IRRuntimeFunction.return32Bytes(value: call)
      }
    }

    return "\(typeStateChecks.description)\n\(callerProtectionChecks)\n\(valueChecks)\(call)"
  }
}

/// Checks if the state is correct for a function to be called.
struct IRTypeStateChecks {
  var typeStates: [TypeState]

  func rendered(enclosingType: RawTypeIdentifier, environment: Environment) -> YUL.Expression {
    let checks = typeStates.compactMap { typeState -> String? in
      guard !typeState.isAny else { return nil }

      let stateValue = IRExpression(expression: environment.getStateValue(typeState.identifier, in: enclosingType),
                                    asLValue: false)
        .rendered(functionContext: FunctionContext(environment: environment,
                                                   scopeContext: ScopeContext(),
                                                   enclosingTypeName: enclosingType,
                                                   isInStructFunction: false))

      let stateVariable: AST.Expression = .identifier(Identifier(name: IRContract.stateVariablePrefix + enclosingType,
                                                             sourceLocation: .DUMMY))
      let selfState: AST.Expression = .binaryExpression(BinaryExpression(
        lhs: .self(Token(kind: .self, sourceLocation: .DUMMY)),
        op: Token(kind: .punctuation(.dot), sourceLocation: .DUMMY),
        rhs: stateVariable))
      let stateVariableRendered = IRExpression(expression: selfState, asLValue: false)
        .rendered(functionContext: FunctionContext(environment: environment,
                                                   scopeContext: ScopeContext(),
                                                   enclosingTypeName: enclosingType,
                                                   isInStructFunction: false))

      let check = IRRuntimeFunction.isMatchingTypeState(stateValue.description, stateVariableRendered.description)
      return "_flintStateCheck := add(_flintStateCheck, \(check))"
    }

    if !checks.isEmpty {
      return .inline(
        """
      let _flintStateCheck := 0
      \(checks.joined(separator: "\n"))
      if eq(_flintStateCheck, 0) { revert(0, 0) }
      """)
    }

    return .inline("")
  }
}
