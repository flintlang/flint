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
  var callerBinding: Identifier?
  var callerProtections: [CallerProtection]

  var environment: Environment

  var isContractFunction: Bool

  var containsAnyCaller: Bool {
    return callerProtections.contains(where: { $0.isAny })
  }

  init(functionDeclaration: FunctionDeclaration,
       typeIdentifier: Identifier,
       typeStates: [TypeState] = [],
       callerBinding: Identifier? = nil,
       callerProtections: [CallerProtection] = [],
       environment: Environment) {
    self.functionDeclaration = functionDeclaration
    self.typeIdentifier = typeIdentifier
    self.typeStates = typeStates
    self.callerBinding = callerBinding
    self.callerProtections = callerProtections
    self.environment = environment
    self.isContractFunction = !callerProtections.isEmpty
  }

  var name: String {
    return functionDeclaration.mangledIdentifier!
  }

  var parameterNames: [String] {
    let fc = FunctionContext(environment: environment,
                             scopeContext: scopeContext,
                             enclosingTypeName: typeIdentifier.name,
                             isInStructFunction: !isContractFunction)
    return functionDeclaration.explicitParameters.map {
        IRIdentifier(identifier: $0.identifier).rendered(functionContext: fc).description
    }
  }

  /// The function's parameters and caller caller binding, as variable declarations in a `ScopeContext`.
  var scopeContext: ScopeContext {
    return functionDeclaration.scopeContext!
  }

  var parameterCanonicalTypes: [CanonicalType] {
    return functionDeclaration.explicitParameters.map({ CanonicalType(from: $0.type.rawType)! })
  }

  var resultCanonicalType: CanonicalType? {
    return functionDeclaration.signature.resultType.flatMap({ CanonicalType(from: $0.rawType)! })
  }

  func rendered() -> String {
    let body = IRFunctionBody(functionDeclaration: functionDeclaration,
                              typeIdentifier: typeIdentifier,
                              callerBinding: callerBinding,
                              callerProtections: callerProtections,
                              environment: environment,
                              isContractFunction: isContractFunction).rendered()

    return """
    function \(signature()) {
      \(body.indented(by: 2))
    }
    """
  }

  func signature(withReturn: Bool = true) -> String {
    let doesReturn = functionDeclaration.signature.resultType != nil && withReturn
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

  var callerBinding: Identifier?
  var callerProtections: [CallerProtection]

  var environment: Environment

  var isContractFunction: Bool

  /// The function's parameters and caller caller binding, as variable declarations in a `ScopeContext`.
  var scopeContext: ScopeContext {
    return functionDeclaration.scopeContext!
  }

  init(functionDeclaration: FunctionDeclaration,
       typeIdentifier: Identifier,
       callerBinding: Identifier?,
       callerProtections: [CallerProtection],
       environment: Environment,
       isContractFunction: Bool) {
     self.functionDeclaration = functionDeclaration
     self.typeIdentifier = typeIdentifier
     self.callerProtections = callerProtections
     self.callerBinding = callerBinding
     self.environment = environment
     self.isContractFunction = isContractFunction
   }

  func rendered() -> String {
    let functionContext: FunctionContext = FunctionContext(environment: environment,
                                                           scopeContext: scopeContext,
                                                           enclosingTypeName: typeIdentifier.name,
                                                           isInStructFunction: !isContractFunction)

    // Assign a caller capaiblity binding to a local variable.
    let callerBindingDeclaration: String
    if let callerBinding = callerBinding {
      callerBindingDeclaration = "let \(callerBinding.name.mangled) := caller()\n"
    } else {
      callerBindingDeclaration = ""
    }

    let body = renderBody(functionDeclaration.body, functionContext: functionContext)

    return "\(callerBindingDeclaration)\(body)"
  }

  func renderBody<S: RandomAccessCollection & RangeReplaceableCollection>(_ statements: S,
                                                                          functionContext: FunctionContext) -> String
    where S.Element == AST.Statement, S.Index == Int {
    guard !statements.isEmpty else { return "" }
    var statements = statements
    var emitLastBrace = false
    while !statements.isEmpty {
      let statement: Statement = statements.removeFirst()
      functionContext.emit(IRStatement(statement: statement).rendered(functionContext: functionContext))
      if case .ifStatement(let ifStatement) = statement,
         ifStatement.endsWithReturnStatement {
        if ifStatement.elseBody.isEmpty {
          functionContext.emit(.inline("default {"))
          emitLastBrace = true
        } else if !statements.isEmpty {
          fatalError("Cannot have an if/else statement which contains a `return' statement and is followed by code")
        }
      }
    }
    if emitLastBrace {
      functionContext.emit(.inline("}"))
    }
    return functionContext.finalise()
  }

}
