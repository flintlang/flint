//
//  IULIAInitializer.swift
//  IRGen
//
//  Created by Franklin Schrans on 4/27/18.
//

import AST

/// Generates code for a contract initializer.
struct IRContractInitializer {
  var initializerDeclaration: SpecialDeclaration
  var typeIdentifier: Identifier

  /// The properties defined in the enclosing type. The default values of each property will be set in the initializer.
  var propertiesInEnclosingType: [VariableDeclaration]

  var capabilityBinding: Identifier?
  var callerCapabilities: [CallerCapability]

  var environment: Environment

  var isContractFunction = false

  var parameterNames: [String] {
    let fc = FunctionContext(environment: environment, scopeContext: scopeContext, enclosingTypeName: typeIdentifier.name, isInStructFunction: !isContractFunction)
    return initializerDeclaration.explicitParameters.map { IRIdentifier(identifier: $0.identifier).rendered(functionContext: fc) }
  }

  /// The function's parameters and caller capability binding, as variable declarations in a `ScopeContext`.
  var scopeContext: ScopeContext {
    var localVariables = [VariableDeclaration]()
    if let capabilityBinding = capabilityBinding {
      localVariables.append(VariableDeclaration(modifiers: [], declarationToken: nil, identifier: capabilityBinding, type: Type(inferredType: .basicType(.address), identifier: capabilityBinding)))
    }
    return ScopeContext(parameters: initializerDeclaration.parameters, localVariables: localVariables)
  }

  func rendered() -> String {
    let parameterSizes = initializerDeclaration.explicitParameters.map { environment.size(of: $0.type.rawType) }
    let offsetsAndSizes = zip(parameterSizes.reversed().reduce((0, [Int]())) { (acc, element) in
      let (size, sizes) = acc
      let nextSize = size + element * EVM.wordSize
      return (nextSize, sizes + [nextSize])
    }.1.reversed(), parameterSizes)

    let parameterBindings = zip(parameterNames, offsetsAndSizes).map { arg -> String in
      let (parameter, (offset, size)) = arg
      return """
      codecopy(0x0, sub(codesize, \(offset)), \(size * EVM.wordSize))
      let \(parameter) := mload(0)
      """
    }.joined(separator: "\n")

    let body = IRFunctionBody(functionDeclaration: initializerDeclaration.asFunctionDeclaration, typeIdentifier: typeIdentifier, capabilityBinding: capabilityBinding, callerCapabilities: callerCapabilities, environment: environment, isContractFunction: isContractFunction).rendered()

    return """
    init()
    function init() {
      \(parameterBindings.indented(by: 2))
      \(body.indented(by: 2))
    }
    """
  }
}
