//
//  IULIAFunction.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/28/17.
//

import AST
import Foundation
import CryptoSwift

/// Generates code for a function.
struct IULIAFunction {
  static let returnVariableName = "ret"

  var functionDeclaration: FunctionDeclaration
  var typeIdentifier: Identifier

  var capabilityBinding: Identifier?
  var callerCapabilities: [CallerCapability]

  var environment: Environment

  var isContractFunction = false

  var functionContext: FunctionContext {
    return FunctionContext(environment: environment, scopeContext: scopeContext, enclosingTypeName: typeIdentifier.name, isInContractFunction: isContractFunction)
  }

  init(functionDeclaration: FunctionDeclaration, typeIdentifier: Identifier, capabilityBinding: Identifier? = nil, callerCapabilities: [CallerCapability] = [], environment: Environment) {
    self.functionDeclaration = functionDeclaration
    self.typeIdentifier = typeIdentifier
    self.capabilityBinding = capabilityBinding
    self.callerCapabilities = callerCapabilities
    self.environment = environment

    if !callerCapabilities.isEmpty {
      isContractFunction = true
    }
  }

  var name: String {
    return functionDeclaration.identifier.name
  }

  var parameterNames: [String] {
    return functionDeclaration.explicitParameters.map { parameter in
      return IULIAIdentifier(identifier: parameter.identifier).rendered(functionContext: functionContext)
    }
  }

  /// The function's parameters and caller capability binding, as variable declarations in a `ScopeContext`.
  var scopeContext: ScopeContext {
    var localVariables = functionDeclaration.parametersAsVariableDeclarations
    if let capabilityBinding = capabilityBinding {
      localVariables.append(VariableDeclaration(declarationToken: nil, identifier: capabilityBinding, type: Type(inferredType: .builtInType(.address), identifier: capabilityBinding)))
    }
    return ScopeContext(localVariables: localVariables)
  }

  var parameterCanonicalTypes: [CanonicalType] {
    return functionDeclaration.explicitParameters.map({ CanonicalType(from: $0.type.rawType)! })
  }

  var resultCanonicalType: CanonicalType? {
    return functionDeclaration.resultType.flatMap({ CanonicalType(from: $0.rawType)! })
  }

  func rendered() -> String {
    let doesReturn = functionDeclaration.resultType != nil
    let parametersString = parameterNames.joined(separator: ", ")
    let signature = "\(name)(\(parametersString)) \(doesReturn ? "-> \(IULIAFunction.returnVariableName)" : "")"

    // Dynamically check the caller has appropriate caller capabilities.
    let callerCapabilityChecks = IULIACallerCapabilityChecks(callerCapabilities: callerCapabilities).rendered(functionContext: functionContext)
    let body = renderBody(functionDeclaration.body, functionContext: functionContext)

    // Assign a caller capaiblity binding to a local variable.
    let capabilityBindingDeclaration: String
    if let capabilityBinding = capabilityBinding {
      capabilityBindingDeclaration = "let \(Mangler.mangleName(capabilityBinding.name)) := caller()\n"
    } else {
      capabilityBindingDeclaration = ""
    }

    // Assign Wei value sent to a @payable function to a local variable.
    let payableValueDeclaration: String
    if let payableValueParameter = functionDeclaration.firstPayableValueParameter {
      payableValueDeclaration = "let \(Mangler.mangleName(payableValueParameter.identifier.name)) := callvalue()\n"
    } else {
      payableValueDeclaration = ""
    }

    return """
    function \(signature) {
      \(callerCapabilityChecks.indented(by: 2))\(payableValueDeclaration.indented(by: 2))\(capabilityBindingDeclaration.indented(by: 2))\(body.indented(by: 2))
    }
    """
  }

  func renderBody<S : RandomAccessCollection & RangeReplaceableCollection>(_ statements: S, functionContext: FunctionContext) -> String where S.Element == AST.Statement, S.Index == Int {
    guard !statements.isEmpty else { return "" }
    var statements = statements
    let first = statements.removeFirst()
    let firstCode = IULIAStatement(statement: first).rendered(functionContext: functionContext)
    let restCode = renderBody(statements, functionContext: functionContext)

    if case .ifStatement(let ifStatement) = first, ifStatement.endsWithReturnStatement {
      let defaultCode = """

      default {
        \(restCode.indented(by: 2))
      }
      """
      return firstCode + (restCode.isEmpty ? "" : defaultCode)
    } else {
      return firstCode + (restCode.isEmpty ? "" : "\n" + restCode)
    }
  }

  /// The string representation of this function's signature, used for generating a IULIA interface.
  func mangledSignature() -> String {
    let name = functionDeclaration.identifier.name
    let parametersString = parameterCanonicalTypes.map({ $0.rawValue }).joined(separator: ",")

    return "\(name)(\(parametersString))"
  }
}

/// Checks whether the caller of a function has appropriate caller capabilities.
struct IULIACallerCapabilityChecks {
  var callerCapabilities: [CallerCapability]

  func rendered(functionContext: FunctionContext) -> String {
    let environment = functionContext.environment

    let checks = callerCapabilities.compactMap { callerCapability -> String? in
      guard !callerCapability.isAny else { return nil }

      let type = environment.type(of: callerCapability.identifier.name, enclosingType: functionContext.enclosingTypeName)!
      let offset = environment.propertyOffset(for: callerCapability.name, enclosingType: functionContext.enclosingTypeName)!
      switch type {
      case .fixedSizeArrayType(_, let size):
        return (0..<size).map { index in
          "_flintCallerCheck := add(_flintCallerCheck, \(IULIARuntimeFunction.isValidCallerCapability.rawValue)(sload(add(\(offset), \(index)))))"
          }.joined(separator: "\n")
      case .arrayType(_):
        return "_flintCallerCheck := add(_flintCallerCheck, \(IULIARuntimeFunction.isCallerCapabilityInArray.rawValue)(\(offset)))"
      default:
        return "_flintCallerCheck := add(_flintCallerCheck, \(IULIARuntimeFunction.isValidCallerCapability.rawValue)(sload(\(offset))))"
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
