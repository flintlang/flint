//
//  IRFunction.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/28/17.
//

import AST
import CryptoSwift

/// Generates code for a function.
struct IRFunction {
  static let returnVariableName = "ret"

  var functionDeclaration: FunctionDeclaration
  var typeIdentifier: Identifier

  var typeStates: [TypeState]
  var capabilityBinding: Identifier?
  var callerCapabilities: [CallerCapability]

  var environment: Environment

  var isContractFunction = false

  var containsAnyCaller: Bool {
    return callerCapabilities.contains(where: { $0.isAny })
  }

  init(functionDeclaration: FunctionDeclaration, typeIdentifier: Identifier, typeStates: [TypeState] = [], capabilityBinding: Identifier? = nil, callerCapabilities: [CallerCapability] = [], environment: Environment) {
    self.functionDeclaration = functionDeclaration
    self.typeIdentifier = typeIdentifier
    self.typeStates = typeStates
    self.capabilityBinding = capabilityBinding
    self.callerCapabilities = callerCapabilities
    self.environment = environment

    if !callerCapabilities.isEmpty {
      isContractFunction = true
    }
  }

  var name: String {
    return functionDeclaration.mangledIdentifier!
  }

  var parameterNames: [String] {
    let fc = FunctionContext(environment: environment, scopeContext: scopeContext, enclosingTypeName: typeIdentifier.name, isInStructFunction: !isContractFunction)
    return functionDeclaration.explicitParameters.map {IRIdentifier(identifier: $0.identifier).rendered(functionContext: fc)}
  }

  /// The function's parameters and caller capability binding, as variable declarations in a `ScopeContext`.
  var scopeContext: ScopeContext {
    return functionDeclaration.scopeContext!
  }

  var parameterCanonicalTypes: [CanonicalType] {
    return functionDeclaration.explicitParameters.map({ CanonicalType(from: $0.type.rawType)! })
  }

  var resultCanonicalType: CanonicalType? {
    return functionDeclaration.resultType.flatMap({ CanonicalType(from: $0.rawType)! })
  }

  func rendered() -> String {
    let body = IRFunctionBody(functionDeclaration: functionDeclaration, typeIdentifier: typeIdentifier, capabilityBinding: capabilityBinding, callerCapabilities: callerCapabilities, environment: environment, isContractFunction: isContractFunction).rendered()

    return """
    function \(signature()) {
      \(body.indented(by: 2))
    }
    """
  }

  func signature(withReturn: Bool = true) -> String {
    let doesReturn = functionDeclaration.resultType != nil && withReturn
     let parametersString = parameterNames.joined(separator: ", ")
     return "\(name)(\(parametersString)) \(doesReturn ? "-> \(IRFunction.returnVariableName)" : "")"
  }

  /// The string representation of this function's signature, used for generating a IR interface.
  func mangledSignature() -> String {
    let name = functionDeclaration.identifier.name
    let parametersString = parameterCanonicalTypes.map({ $0.rawValue }).joined(separator: ",")

    return "\(name)(\(parametersString))"
  }
}

struct IRFunctionBody {
  var functionDeclaration: FunctionDeclaration
  var typeIdentifier: Identifier

  var capabilityBinding: Identifier?
  var callerCapabilities: [CallerCapability]

  var environment: Environment

  var isContractFunction = false

  /// The function's parameters and caller capability binding, as variable declarations in a `ScopeContext`.
  var scopeContext: ScopeContext {
    return functionDeclaration.scopeContext!
  }

  init(functionDeclaration: FunctionDeclaration, typeIdentifier: Identifier, capabilityBinding: Identifier?, callerCapabilities: [CallerCapability], environment: Environment, isContractFunction: Bool) {
     self.functionDeclaration = functionDeclaration
     self.typeIdentifier = typeIdentifier
     self.callerCapabilities = callerCapabilities
     self.capabilityBinding = capabilityBinding
     self.environment = environment
     self.isContractFunction = isContractFunction
   }

  func rendered() -> String {
    let functionContext: FunctionContext = FunctionContext(environment: environment, scopeContext: scopeContext, enclosingTypeName: typeIdentifier.name, isInStructFunction: !isContractFunction)

    // Assign a caller capaiblity binding to a local variable.
    let capabilityBindingDeclaration: String
    if let capabilityBinding = capabilityBinding {
      capabilityBindingDeclaration = "let \(capabilityBinding.name.mangled) := caller()\n"
    } else {
      capabilityBindingDeclaration = ""
    }

    let body = renderBody(functionDeclaration.body, functionContext: functionContext)

    return "\(capabilityBindingDeclaration)\(body)"
  }

  func renderBody<S : RandomAccessCollection & RangeReplaceableCollection>(_ statements: S, functionContext: FunctionContext) -> String where S.Element == AST.Statement, S.Index == Int {
    guard !statements.isEmpty else { return "" }
    var statements = statements
    let first = statements.removeFirst()
    let firstCode = IRStatement(statement: first).rendered(functionContext: functionContext)
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
}
