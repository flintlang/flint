//
//  IULIAInitializer.swift
//  MoveGen
//
//  Created by Franklin Schrans on 4/27/18.
//

import AST

/// Generates code for a contract initializer.
struct MoveContractInitializer {
  var initializerDeclaration: SpecialDeclaration
  var typeIdentifier: Identifier

  /// The properties defined in the enclosing type. The default values of each property will be set in the initializer.
  var propertiesInEnclosingType: [VariableDeclaration]

  var callerBinding: Identifier?
  var callerProtections: [CallerProtection]

  var environment: Environment

  var isContractFunction = false

  var parameterNames: [String] {
    let fc = FunctionContext(environment: environment,
                             scopeContext: scopeContext,
                             enclosingTypeName: typeIdentifier.name,
                             isInStructFunction: !isContractFunction)
    return initializerDeclaration.explicitParameters.map {
        MoveIdentifier(identifier: $0.identifier).rendered(functionContext: fc).description
    }
  }

  var parameterCanonicalTypes: [CanonicalType] {
    return initializerDeclaration.explicitParameters.map { CanonicalType(from: $0.type.rawType)! }
  }

  /// The function's parameters and caller binding, as variable declarations in a `ScopeContext`.
  var scopeContext: ScopeContext {
    var localVariables = [VariableDeclaration]()
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

    let body = MoveInitializerBody(declaration: initializerDeclaration,
                              typeIdentifier: typeIdentifier,
                              callerBinding: callerBinding,
                              callerProtections: callerProtections,
                              environment: environment).rendered() // We need a separate function body for constructors

    return """
    new(\(parameters)) -> R#Self.T {
      \(body.indented(by: 2))
    }
    """
  }
}

struct MoveInitializerBody {
  var declaration: SpecialDeclaration
  var typeIdentifier: Identifier

  var callerBinding: Identifier?
  var callerProtections: [CallerProtection]

  var environment: Environment

  /// The function's parameters and caller caller binding, as variable declarations in a `ScopeContext`.
  var scopeContext: ScopeContext {
    return declaration.scopeContext
  }

  init(declaration: SpecialDeclaration,
       typeIdentifier: Identifier,
       callerBinding: Identifier?,
       callerProtections: [CallerProtection],
       environment: Environment) {
    self.declaration = declaration
    self.typeIdentifier = typeIdentifier
    self.callerProtections = callerProtections
    self.callerBinding = callerBinding
    self.environment = environment
  }

  func rendered() -> String {
    let functionContext: FunctionContext = FunctionContext(environment: environment,
                                                           scopeContext: scopeContext,
                                                           enclosingTypeName: typeIdentifier.name,
                                                           isInStructFunction: false)

    // Assign a caller capaiblity binding to a local variable.
    let callerBindingDeclaration: String
    if let callerBinding = callerBinding {
      callerBindingDeclaration = "let \(callerBinding.name.mangled) = get_txn_sender();\n"
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
    var statements = statements
    while !statements.isEmpty {
      let statement = statements.removeFirst()
      functionContext.emit(MoveStatement(statement: statement).rendered(functionContext: functionContext))
    }
    return functionContext.finalise()
  }

}
