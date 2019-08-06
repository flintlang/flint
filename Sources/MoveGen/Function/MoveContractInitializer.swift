//
//  IULIAInitializer.swift
//  MoveGen
//
//  Created by Franklin Schrans on 4/27/18.
//

import AST
import MoveIR

/// Generates code for a contract initializer.
struct MoveContractInitializer {
  var initializerDeclaration: SpecialDeclaration
  var typeIdentifier: AST.Identifier

  /// The properties defined in the enclosing type. The default values of each property will be set in the initializer.
  var propertiesInEnclosingType: [AST.VariableDeclaration]

  var callerBinding: AST.Identifier?
  var callerProtections: [CallerProtection]

  var environment: Environment

  var isContractFunction = false

  var contract: MoveContract

  var parameterNames: [String] {
    let fc = FunctionContext(environment: environment,
                             scopeContext: scopeContext,
                             enclosingTypeName: typeIdentifier.name,
                             isInStructFunction: !isContractFunction)
//                             isConstructor: true)
    return initializerDeclaration.explicitParameters.map {
        MoveIdentifier(identifier: $0.identifier).rendered(functionContext: fc).description
    }
  }

  var parameterCanonicalTypes: [CanonicalType] {
    return initializerDeclaration.explicitParameters.map { CanonicalType(from: $0.type.rawType,
                                                                         environment: environment)! }
  }

  /// The function's parameters and caller binding, as variable declarations in a `ScopeContext`.
  var scopeContext: ScopeContext {
    var localVariables = [AST.VariableDeclaration]()
    if let callerBinding = callerBinding {
      let variableDeclaration = VariableDeclaration(modifiers: [],
                                                    declarationToken: nil,
                                                    identifier: callerBinding,
                                                    type: Type(inferredType: .basicType(.address),
                                                               identifier: callerBinding))
      localVariables.append(variableDeclaration)
    }
    return ScopeContext(parameters: initializerDeclaration.signature.parameters, localVariables: localVariables)
  }

  func rendered() -> String {
    /* let parameterSizes = initializerDeclaration.explicitParameters.map { environment.size(of: $0.type.rawType) }
    let offsetsAndSizes = zip(parameterSizes.reversed().reduce((0, [Int]())) { (acc, element) in
      let (size, sizes) = acc
      let nextSize = size + element * EVM.wordSize
      return (nextSize, sizes + [nextSize])
    }.1.reversed(), parameterSizes)*/

    let parameters = zip(parameterNames, parameterCanonicalTypes).map { param in
      let (name, type): (String, CanonicalType) = param
      return "\(name): \(type)"
    }.joined(separator: ", ")

    let body = MoveInitializerBody(
        declaration: initializerDeclaration,
        typeIdentifier: typeIdentifier,
        callerBinding: callerBinding,
        callerProtections: callerProtections,
        environment: environment,
        properties: contract.contractDeclaration.variableDeclarations
    ).rendered()

    return """
    new(\(parameters)): R#Self.T {
      \(body.indented(by: 2))
    }
    """
  }
}

struct MoveInitializerBody {
  var declaration: SpecialDeclaration
  var typeIdentifier: AST.Identifier

  var callerBinding: AST.Identifier?
  var callerProtections: [CallerProtection]

  var environment: Environment
  let properties: [AST.VariableDeclaration]

  /// The function's parameters and caller caller binding, as variable declarations in a `ScopeContext`.
  var scopeContext: ScopeContext {
    return declaration.scopeContext
  }

  init(declaration: SpecialDeclaration,
       typeIdentifier: AST.Identifier,
       callerBinding: AST.Identifier?,
       callerProtections: [CallerProtection],
       environment: Environment,
       properties: [AST.VariableDeclaration]) {
    self.declaration = declaration
    self.typeIdentifier = typeIdentifier
    self.callerProtections = callerProtections
    self.callerBinding = callerBinding
    self.environment = environment
    self.properties = properties
  }

  func rendered() -> String {
    let functionContext: FunctionContext = FunctionContext(environment: environment,
                                                           scopeContext: scopeContext,
                                                           enclosingTypeName: typeIdentifier.name,
                                                           isConstructor: true)

    // Assign a caller capaiblity binding to a local variable.
    let callerBindingDeclaration: String
    if let callerBinding = callerBinding {
      callerBindingDeclaration = "let \(callerBinding.name.mangled) = get_txn_sender()\(Move.statementLineSeparator)"
    } else {
      callerBindingDeclaration = ""
    }

    let body = renderBody(declaration.body, functionContext: functionContext)

    return "\(callerBindingDeclaration)\(body)"
  }

  func renderBody<S: RandomAccessCollection & RangeReplaceableCollection>(_ statements: S,
                                                                          functionContext: FunctionContext) -> String
      where S.Element == AST.Statement, S.Index == Int {
    guard !statements.isEmpty else { return "" }
    var declarations = self.properties
    var statements = statements

    while !declarations.isEmpty {
      let property: AST.VariableDeclaration = declarations.removeFirst()
      functionContext.emit(.expression(.variableDeclaration(
          MoveIR.VariableDeclaration((
              property.identifier.name.mangled,
              CanonicalType(from: property.type.rawType, environment: environment)!.irType
          ), nil)
      )))
    }

    while !statements.isEmpty {
      let statement = statements.removeFirst()
      functionContext.emit(MoveStatement(statement: statement).rendered(functionContext: functionContext))
    }
    functionContext.emit(.return(.structConstructor(MoveIR.StructConstructor(
        "T",
        Dictionary(uniqueKeysWithValues: properties.map {
              ($0.identifier.name, .identifier($0.identifier.name.mangled))
            })
    ))))
    return functionContext.finalise()
  }

}
