//
//  IULIAInitializer.swift
//  IRGen
//
//  Created by Franklin Schrans on 4/27/18.
//

import AST

/// Generates code for a contract initializer.
struct IULIAContractInitializer {
  var initializerDeclaration: InitializerDeclaration
  var typeIdentifier: Identifier

  /// The properties defined in the enclosing type. The default values of each property will be set in the initializer.
  var propertiesInEnclosingType: [VariableDeclaration]

  var capabilityBinding: Identifier?
  var callerCapabilities: [CallerCapability]

  var environment: Environment

  var isContractFunction = false

  var functionContext: FunctionContext {
    return FunctionContext(environment: environment, scopeContext: scopeContext, enclosingTypeName: typeIdentifier.name, isInStructFunction: !isContractFunction)
  }

  var parameterNames: [String] {
    return initializerDeclaration.explicitParameters.map { parameter in
      return IULIAIdentifier(identifier: parameter.identifier).rendered(functionContext: functionContext)
    }
  }

  /// The function's parameters and caller capability binding, as variable declarations in a `ScopeContext`.
  var scopeContext: ScopeContext {
    var localVariables = [VariableDeclaration]()
    if let capabilityBinding = capabilityBinding {
      localVariables.append(VariableDeclaration(declarationToken: nil, identifier: capabilityBinding, type: Type(inferredType: .basicType(.address), identifier: capabilityBinding)))
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

    let defaultValuesAssignments = renderDefaultValuesAssignments()

    let body = IULIAFunctionBody(functionDeclaration: initializerDeclaration.asFunctionDeclaration, typeIdentifier: typeIdentifier, capabilityBinding: capabilityBinding, callerCapabilities: callerCapabilities, environment: environment, isContractFunction: isContractFunction).rendered()

    // TODO: Remove IULIARuntimeFunctionDeclaration.store once constructor code and function code is unified.

    return """
    \(parameterBindings)
    \(defaultValuesAssignments)
    \(body)
    \(IULIARuntimeFunctionDeclaration.store)
    """
  }

  func renderDefaultValuesAssignments() -> String {
    let defaultValueAssignments = propertiesInEnclosingType.compactMap { declaration -> String? in
      guard let assignedExpression = declaration.assignedExpression else { return nil }

      var identifier = declaration.identifier
      identifier.enclosingType = typeIdentifier.name

      return IULIAAssignment(lhs: .identifier(identifier), rhs: assignedExpression).rendered(functionContext: functionContext, asTypeProperty: true)
    }

    return defaultValueAssignments.joined(separator: "\n")
  }
}
