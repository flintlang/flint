//
//  MoveFunction.swift
//  MoveGen
//
//  Created by Franklin Schrans on 12/28/17.
//

import AST
import CryptoSwift
import Lexer

/// Generates code for a function.
struct MoveFunction {
  // TODO Remove if not eventually needed
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
        MoveIdentifier(identifier: $0.identifier, position: .left).rendered(functionContext: fc).description
    }
  }

  /// The function's parameters and caller caller binding, as variable declarations in a `ScopeContext`.
  var scopeContext: ScopeContext {
    return functionDeclaration.scopeContext!
  }

  var parameterCanonicalTypes: [CanonicalType] {
    return functionDeclaration.explicitParameters.map({ CanonicalType(from: $0.type.rawType,
                                                                      environment: environment)! })
  }

  var resultCanonicalType: CanonicalType? {
    return functionDeclaration.signature.resultType.flatMap({ CanonicalType(from: $0.rawType,
                                                                            environment: environment)! })
  }

  func rendered() -> String {
    let body = MoveFunctionBody(functionDeclaration: functionDeclaration,
                              typeIdentifier: typeIdentifier,
                              callerBinding: callerBinding,
                              callerProtections: callerProtections,
                              environment: environment,
                              isContractFunction: isContractFunction).rendered()

    return """
    \(signature()) {
      \(body.indented(by: 2))
    }
    """
  }

  func signature(withReturn: Bool = true) -> String {
    let functionContext: FunctionContext = FunctionContext(environment: environment,
                                                           scopeContext: scopeContext,
                                                           enclosingTypeName: typeIdentifier.name,
                                                           isInStructFunction: !isContractFunction)
    let parametersString = zip(parameterNames, parameterCanonicalTypes).map { param in
      let (name, type): (String, CanonicalType) = param
      return "\(name): \(type.render(functionContext: functionContext))"
    }.joined(separator: ", ")
    let modifiers = functionDeclaration.signature.modifiers
        .compactMap { (modifier: Token) -> String? in
      switch modifier.kind {
      case .public: return "public "
      default: return nil
      }
    }.reduce("", +)
    let returnType = functionDeclaration.signature.resultType != nil && withReturn
        ? ": \(resultCanonicalType!.render(functionContext: functionContext))"
        : ""
    let tags = functionDeclaration.compilerTags.reduce("") { $0 + " " + $1 }
    return "\(modifiers)\(name)(\(parametersString))\(returnType)\(tags)"
  }

  /// The string representation of this function's signature, used for generating a IR interface.
  func mangledSignature() -> String {
    let functionContext: FunctionContext = FunctionContext(environment: environment,
                                                           scopeContext: scopeContext,
                                                           enclosingTypeName: typeIdentifier.name,
                                                           isInStructFunction: !isContractFunction)
    let name = functionDeclaration.identifier.name
    let parametersString = zip(parameterNames, parameterCanonicalTypes).map { param in
      let (name, type): (String, CanonicalType) = param
      return "\(name): \(type.render(functionContext: functionContext))"
    }.joined(separator: ", ")
    return "\(name)(\(parametersString))"
  }
}

struct MoveFunctionBody {
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
    return renderBody(functionDeclaration.body, functionContext: functionContext)
  }

  func renderBody<S: RandomAccessCollection & RangeReplaceableCollection>(_ statements: S,
                                                                          functionContext: FunctionContext) -> String
    where S.Element == AST.Statement, S.Index == Int {
    guard !statements.isEmpty else { return "" }
    var statements = statements
    while !statements.isEmpty {
      let statement = statements.removeFirst()
      functionContext.emit(MoveStatement(statement: statement).rendered(functionContext: functionContext))
    }
    return functionContext.finalise()
  }

}
