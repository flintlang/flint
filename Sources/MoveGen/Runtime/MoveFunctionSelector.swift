//
//  MoveFunctionSelector.swift
//  MoveGen
//
//  Created by Franklin Schrans on 12/28/17.
//

import AST
import Lexer
import ABI
import MoveIR

/// Runtime code in IR which determines which function to call based on the Ethereum's transaction payload.
struct MoveFunctionSelector {
  var fallback: SpecialDeclaration?
  var functions: [MoveFunction]
  var enclosingType: AST.Identifier
  var environment: Environment

  func rendered() -> String {
    let reentrancyProtection = renderReentrancyProtection()
    let cases = renderCases()
    let fallback = renderFallback()

    return """
    \(reentrancyProtection)
    switch \(MoveRuntimeFunction.selector())
    \(cases)
    default {
      \(fallback)
    }
    """
  }

  func renderReentrancyProtection() -> String {
    let reentrancyProtection = MoveReentrancyProtection()
        .rendered(enclosingType: enclosingType.name, environment: environment)
    return reentrancyProtection.description
  }

  func renderFallback() -> String {
    if let fallbackDeclaration = fallback {
      return MoveContractFallback(fallbackDeclaration: fallbackDeclaration,
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

  func renderCaseBody(function: MoveFunction) -> String {
    // Dynamically check that the state is correct for the function to be called.
    let typeStates = function.typeStates
    let typeStateChecks = MoveTypeStateChecks(typeStates: typeStates)
        .rendered(enclosingType: enclosingType.name, environment: environment)

    // Dynamically check the caller has appropriate caller protections.
    let callerProtections = function.callerProtections
    let callerProtectionChecks = MoveCallerProtectionChecks(callerProtections: callerProtections)
        .rendered(enclosingType: enclosingType.name, environment: environment)

    // Dynamically check the function is not being called with value, if it is not payable.
    let valueChecks: String
    if !function.functionDeclaration.isPayable {
      valueChecks = MoveRuntimeFunction.checkNoValue(MoveRuntimeFunction.callvalue()) + "\n"
    } else {
      valueChecks = ""
    }

    let arguments = function.parameterCanonicalTypes.map { $0.irType.description }
    let wrapperPrefix = function.containsAnyCaller ? "" : "\(MoveWrapperFunction.prefixHard)"
    let call =  "\(wrapperPrefix)\(function.name)(\(arguments.joined(separator: ", ")))"

    if let resultType = function.resultCanonicalType {
      "\(typeStateChecks.description)\n\(callerProtectionChecks)\n\(valueChecks)\(call): \(resultType.irType)"
    }
    return "\(typeStateChecks.description)\n\(callerProtectionChecks)\n\(valueChecks)\(call)"
  }
}

/// Checks that we are not inside a non-reentrant external call.
struct MoveReentrancyProtection {
  func rendered(enclosingType: RawTypeIdentifier, environment: Environment) -> MoveIR.Statement {
    let stateVariable: AST.Expression = .identifier(Identifier(name: MoveContract.stateVariablePrefix + enclosingType,
                                                           sourceLocation: .DUMMY))
    let selfState: AST.Expression = .binaryExpression(BinaryExpression(
      lhs: .self(Token(kind: .self, sourceLocation: .DUMMY)),
      op: Token(kind: .punctuation(.dot), sourceLocation: .DUMMY),
      rhs: stateVariable))
    let stateVariableRendered = MoveExpression(expression: selfState, asLValue: false)
      .rendered(functionContext: FunctionContext(environment: environment,
                                                 scopeContext: ScopeContext(),
                                                 enclosingTypeName: enclosingType,
                                                 isInStructFunction: false))

    return .inline("""
    if eq(\(stateVariableRendered.description), \(MoveContract.reentrancyProtectorValue)) { revert(0, 0) }
    """)
  }
}

/// Checks if the state is correct for a function to be called.
struct MoveTypeStateChecks {
  var typeStates: [TypeState]

  func rendered(enclosingType: RawTypeIdentifier, environment: Environment) -> MoveIR.Statement {
    let checks = typeStates.compactMap { typeState -> String? in
      guard !typeState.isAny else { return nil }

      let stateValue = MoveExpression(expression: environment.getStateValue(typeState.identifier, in: enclosingType),
                                    asLValue: false)
        .rendered(functionContext: FunctionContext(environment: environment,
                                                   scopeContext: ScopeContext(),
                                                   enclosingTypeName: enclosingType,
                                                   isInStructFunction: false))

      let stateVariable: AST.Expression = .identifier(Identifier(name: MoveContract.stateVariablePrefix + enclosingType,
                                                             sourceLocation: .DUMMY))
      let selfState: AST.Expression = .binaryExpression(BinaryExpression(
        lhs: .self(Token(kind: .self, sourceLocation: .DUMMY)),
        op: Token(kind: .punctuation(.dot), sourceLocation: .DUMMY),
        rhs: stateVariable))
      let stateVariableRendered = MoveExpression(expression: selfState, asLValue: false)
        .rendered(functionContext: FunctionContext(environment: environment,
                                                   scopeContext: ScopeContext(),
                                                   enclosingTypeName: enclosingType,
                                                   isInStructFunction: false))

      let check = MoveRuntimeFunction.isMatchingTypeState(stateValue.description, stateVariableRendered.description)
      return "_flintStateCheck := add(_flintStateCheck, \(check))"
    }

    if !checks.isEmpty {
      return .inline("""
      let _flintStateCheck := 0
      \(checks.joined(separator: "\n"))
      if eq(_flintStateCheck, 0) { revert(0, 0) }
      """)
    }

    return .noop
  }
}
