//
//  IRCallerCapabilityChecks.swift
//  IRGen
//
//  Created by Hails, Daniel R on 31/07/2018.
//

import AST
import Lexer

/// Checks if the state is correct for a function to be called.
struct IRTypeStateChecks {
  var typeStates: [TypeState]

  func rendered(enclosingType: RawTypeIdentifier, environment: Environment) -> String {
    let checks = typeStates.compactMap { typeState -> String? in
      guard !typeState.isAny else { return nil }

      let stateValue = IRExpression(expression: environment.getStateValue(typeState.identifier, in: enclosingType), asLValue: false).rendered(functionContext: FunctionContext(environment: environment, scopeContext: ScopeContext(), enclosingTypeName: enclosingType, isInStructFunction: false))

      let stateVariable: Expression = .identifier(Identifier(name: IRContract.stateVariablePrefix + enclosingType, sourceLocation: .DUMMY))
      let selfState: Expression = .binaryExpression(BinaryExpression(lhs: .self(Token(kind: .self, sourceLocation: .DUMMY)), op: Token(kind: .punctuation(.dot), sourceLocation: .DUMMY), rhs: stateVariable))
      let stateVariableRendered = IRExpression(expression: selfState, asLValue: false).rendered(functionContext: FunctionContext(environment: environment, scopeContext: ScopeContext(), enclosingTypeName: enclosingType, isInStructFunction: false))

      let check = IRRuntimeFunction.isMatchingTypeState(stateValue, stateVariableRendered)
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
