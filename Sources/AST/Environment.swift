//
//  Environment.swift
//  AST
//
//  Created by Franklin Schrans on 12/26/17.
//

/// Information about the source program.
public struct Environment {
  /// Information about each type (contracts and structs) which the program define, such as its properties and
  /// functions.
  var types = [RawTypeIdentifier: TypeInformation]()

  /// The offset tables used to represent each type at runtime.
  var offsets = [RawTypeIdentifier: OffsetTable]()

  /// A list of the names of the contracts which have been declared in the program.
  var declaredContracts = [Identifier]()

  /// A list of the names of the structs which have been declared in the program.
  var declaredStructs = [Identifier]()

  /// The name of the stdlib struct which contains all global functions.
  public static let globalFunctionStructName = "Flint$Global"

  /// The prefix for Flint runtime functions.
  public static var runtimeFunctionPrefix = "flint$"

  /// Whether the given function call is a runtime function.
  public static func isRuntimeFunctionCall(_ functionCall: FunctionCall) -> Bool {
    return functionCall.identifier.name.starts(with: runtimeFunctionPrefix)
  }

  public init() {}

  /// Add a contract declaration to the environment.
  public mutating func addContract(_ contractDeclaration: ContractDeclaration) {
    declaredContracts.append(contractDeclaration.identifier)
    types[contractDeclaration.identifier.name] = TypeInformation()
    setProperties(contractDeclaration.variableDeclarations, enclosingType: contractDeclaration.identifier.name)
  }

  /// Add a struct declaration to the environment.
  public mutating func addStruct(_ structDeclaration: StructDeclaration) {
    declaredStructs.append(structDeclaration.identifier)
    if types[structDeclaration.identifier.name] == nil {
      types[structDeclaration.identifier.name] = TypeInformation()
    }
    setProperties(structDeclaration.variableDeclarations, enclosingType: structDeclaration.identifier.name)
    for functionDeclaration in structDeclaration.functionDeclarations {
      addFunction(functionDeclaration, enclosingType: structDeclaration.identifier.name)
    }
  }

  /// Add a function declaration to a type (contract or struct). In the case of a contract, a list of caller
  /// capabilities is expected.
  public mutating func addFunction(_ functionDeclaration: FunctionDeclaration, enclosingType: RawTypeIdentifier, callerCapabilities: [CallerCapability] = []) {
    let functionName = functionDeclaration.identifier.name

    types[enclosingType, default: TypeInformation()]
      .functions[functionName, default: [FunctionInformation]()]
      .append(FunctionInformation(declaration: functionDeclaration, callerCapabilities: callerCapabilities, isMutating: functionDeclaration.isMutating))
  }

  /// Add an initializer declaration to a type (contract or struct). In the case of a contract, a list of caller
  /// capabilities is expected.
  public mutating func addInitializer(_ initializerDeclaration: InitializerDeclaration, enclosingType: RawTypeIdentifier, callerCapabilities: [CallerCapability] = []) {
    types[enclosingType, default: TypeInformation()].initializers.append(InitializerInformation(declaration: initializerDeclaration, callerCapabilities: callerCapabilities))
  }

  /// Add a list of properties to a type.
  mutating func setProperties(_ variableDeclarations: [VariableDeclaration], enclosingType: RawTypeIdentifier) {
    types[enclosingType]!.orderedProperties = variableDeclarations.map { $0.identifier.name }
    for variableDeclaration in variableDeclarations {
      addProperty(variableDeclaration, enclosingType: enclosingType)
    }
  }

  /// Add a property to a type.
  mutating func addProperty(_ variableDeclaration: VariableDeclaration, enclosingType: RawTypeIdentifier) {
    if types[enclosingType]!.properties[variableDeclaration.identifier.name] == nil {
      types[enclosingType]!.properties[variableDeclaration.identifier.name] = PropertyInformation(variableDeclaration: variableDeclaration)
    }
  }

  /// Add a use of an undefined variable.
  public mutating func addUsedUndefinedVariable(_ variable: Identifier, enclosingType: RawTypeIdentifier) {
    addProperty(VariableDeclaration(declarationToken: nil, identifier: variable, type: Type(inferredType: .errorType, identifier: variable)), enclosingType: enclosingType)
  }

  /// Whether a contract has been declared in the program.
  public func isContractDeclared(_ type: RawTypeIdentifier) -> Bool {
    return declaredContracts.contains { $0.name == type }
  }

  /// Whether a struct has been declared in the program.
  public func isStructDeclared(_ type: RawTypeIdentifier) -> Bool {
    return declaredStructs.contains { $0.name == type }
  }

  /// Whether a function call refers to an initializer.
  public func isInitializerCall(_ functionCall: FunctionCall) -> Bool {
    return isStructDeclared(functionCall.identifier.name)
  }

  /// Whether a property is defined in a type.
  public func isPropertyDefined(_ property: String, enclosingType: RawTypeIdentifier) -> Bool {
    return types[enclosingType]!.properties.keys.contains(property)
  }

  /// Whether is property is declared as a constnat.
  public func isPropertyConstant(_ property: String, enclosingType: RawTypeIdentifier) -> Bool {
    return types[enclosingType]!.properties[property]!.isConstant
  }

  public func isPropertyAssignedDefaultValue(_ property: String, enclosingType: RawTypeIdentifier) -> Bool {
    return types[enclosingType]!.properties[property]!.isAssignedDefaultValue
  }

  /// The source location of a property declaration.
  public func propertyDeclarationSourceLocation(_ property: String, enclosingType: RawTypeIdentifier) -> SourceLocation? {
    return types[enclosingType]!.properties[property]!.sourceLocation
  }

  /// The names of the properties declared in a type.
  public func properties(in enclosingType: RawTypeIdentifier) -> [String] {
    return types[enclosingType]!.orderedProperties
  }

  /// The list of property declarations in a type.
  public func propertyDeclarations(in enclosingType: RawTypeIdentifier) -> [VariableDeclaration] {
    return types[enclosingType]!.properties.values.map { $0.variableDeclaration }
  }

  private func isRedeclaration(_ identifier1: Identifier, _ identifier2: Identifier) -> Bool {
    return identifier1 != identifier2 &&
      identifier1.name == identifier2.name &&
      identifier1.sourceLocation.line < identifier2.sourceLocation.line
  }

  private func conflictingDeclaration(of identifier: Identifier, in identifiers: [Identifier]) -> Identifier? {
    return identifiers
      .filter({ isRedeclaration($0, identifier) })
      .lazy.sorted(by: { $0.sourceLocation.line < $1.sourceLocation.line }).first
  }

  /// Attempts to find a conflicting declaration of the given type.
  public func conflictingTypeDeclaration(for type: Identifier) -> Identifier? {
    return conflictingDeclaration(of: type, in: declaredStructs + declaredContracts)
  }

  /// Attempts to find a conflicting declaration of the given function declaration
  public func conflictingFunctionDeclaration(for function: FunctionDeclaration, in type: RawTypeIdentifier) -> Identifier? {
    var contractFunctions = [Identifier]()

    if isContractDeclared(type) {
      // Contract functions do not support overloading.
      contractFunctions = types[type]!.functions[function.identifier.name]?.map { $0.declaration.identifier } ?? []
    }

    if let conflict = conflictingDeclaration(of: function.identifier, in: contractFunctions + declaredStructs + declaredContracts) {
      return conflict
    }

    let functions = types[type]!.functions[function.identifier.name]?.filter { functionInformation in
      let identifier1 = function.identifier
      let identifier2 = functionInformation.declaration.identifier
      let parameterList1 = function.parameters.map { $0.type.rawType.name }
      let parameterList2 = functionInformation.declaration.parameters.map { $0.type.rawType.name }

      return identifier1.name == identifier2.name &&
        parameterList1 == parameterList2 &&
        identifier1.sourceLocation.line < identifier2.sourceLocation.line
    }

    return functions?.first?.declaration.identifier
  }

  /// Attempts to find a conflicting declaration of the given property declaration.
  public func conflictingPropertyDeclaration(for identifier: Identifier, in type: RawTypeIdentifier) -> Identifier? {
    return conflictingDeclaration(of: identifier, in: propertyDeclarations(in: type).map { $0.identifier })
  }

  /// The list of initializers in a type.
  public func initializers(in enclosingType: RawTypeIdentifier) -> [InitializerInformation] {
    return types[enclosingType]!.initializers
  }

  /// The list of properties declared in a type which can be used as caller capabilities.
  func declaredCallerCapabilities(enclosingType: RawTypeIdentifier) -> [String] {
    return types[enclosingType]!.properties.compactMap { key, value in
      switch value.rawType {
      case .basicType(.address): return key
      case .fixedSizeArrayType(.basicType(.address), _): return key
      case .arrayType(.basicType(.address)): return key
      default: return nil
      }
    }
  }

  /// Whether the given caller capability is declared in the given type.
  public func containsCallerCapability(_ callerCapability: CallerCapability, enclosingType: RawTypeIdentifier) -> Bool {
    return declaredCallerCapabilities(enclosingType: enclosingType).contains(callerCapability.name)
  }

  /// The type of a property in the given enclosing type or in a scope if it is a local variable.
  public func type(of property: String, enclosingType: RawTypeIdentifier, scopeContext: ScopeContext? = nil) -> Type.RawType {
    if let type = types[enclosingType]?.properties[property]?.rawType {
      return type
    }
    
    guard let scopeContext = scopeContext, let type = scopeContext.type(for: property) else { return .errorType }
    return type
  }

  /// The type return type of a function call, determined by looking up the function's declaration.
  public func type(of functionCall: FunctionCall, enclosingType: RawTypeIdentifier, callerCapabilities: [CallerCapability], scopeContext: ScopeContext) -> Type.RawType? {
    let match = matchFunctionCall(functionCall, enclosingType: enclosingType, callerCapabilities: callerCapabilities, scopeContext: scopeContext)
    
    switch match {
    case .matchedFunction(let matchingFunction): return matchingFunction.resultType
    case .matchedInitializer(_):
      let name = functionCall.identifier.name
      if let stdlibType = Type.StdlibType(rawValue: name) {
        return .stdlibType(stdlibType)
      }
      return .userDefinedType(name)
    default: return .errorType
    }
  }

  /// The types a literal token can be.
  public func type(ofLiteralToken literalToken: Token) -> Type.RawType {
    guard case .literal(let literal) = literalToken.kind else { fatalError() }
    switch literal {
    case .boolean(_): return .basicType(.bool)
    case .decimal(.integer(_)): return .basicType(.int)
    case .string(_): return .basicType(.string)
    default: fatalError()
    }
  }

  // The type of an array literal.
  public func type(ofArrayLiteral arrayLiteral: ArrayLiteral, enclosingType: RawTypeIdentifier, scopeContext: ScopeContext) -> Type.RawType {
    var elementType: Type.RawType?

    for element in arrayLiteral.elements {
      let _type = type(of: element, enclosingType: enclosingType, scopeContext: scopeContext)

      if let elementType = elementType, elementType != _type {
        // The elements have different types.
        return .errorType
      }

      if elementType == nil {
        elementType = _type
      }
    }

    return .arrayType(elementType ?? .any)
  }

  // The type of a dictionary literal.
  public func type(ofDictionaryLiteral dictionaryLiteral: DictionaryLiteral, enclosingType: RawTypeIdentifier, scopeContext: ScopeContext) -> Type.RawType {
    var keyType: Type.RawType?
    var valueType: Type.RawType?

    for element in dictionaryLiteral.elements {
      let _keyType = type(of: element.key, enclosingType: enclosingType, scopeContext: scopeContext)
      let _valueType = type(of: element.value, enclosingType: enclosingType, scopeContext: scopeContext)

      if let _keyType = keyType, _keyType != keyType {
        // The keys have conflicting types.
        return .errorType
      }

      if let _valueType = valueType, _valueType != valueType {
        // The values have conflicting types.
        return .errorType
      }

      if keyType == nil {
        keyType = _keyType
      }

      if valueType == nil {
        valueType = _valueType
      }
    }

    return .dictionaryType(key: keyType ?? .any, value: valueType ?? .any)
  }

  /// The type of an expression.
  ///
  /// - Parameters:
  ///   - expression: The expression to compute the type for.
  ///   - functionDeclarationContext: Contextual information if the expression is used in a function.
  ///   - enclosingType: The enclosing type of the expression, if any.
  ///   - callerCapabilities: The caller capabilities associated with the expression, if the expression is a function call.
  ///   - scopeContext: Contextual information about the scope in which the expression resides.
  /// - Returns: The `Type.RawType` of the expression.
  public func type(of expression: Expression, enclosingType: RawTypeIdentifier, callerCapabilities: [CallerCapability] = [], scopeContext: ScopeContext) -> Type.RawType {

    switch expression {
    case .inoutExpression(let inoutExpression):
      return .inoutType(type(of: inoutExpression.expression, enclosingType: enclosingType, callerCapabilities: callerCapabilities, scopeContext: scopeContext))
    case .binaryExpression(let binaryExpression):
      if binaryExpression.opToken.isBooleanOperator {
        return .basicType(.bool)
      }
      return type(of: binaryExpression.rhs, enclosingType: enclosingType, callerCapabilities: callerCapabilities, scopeContext: scopeContext)

    case .bracketedExpression(let expression):
      return type(of: expression, enclosingType: enclosingType, callerCapabilities: callerCapabilities, scopeContext: scopeContext)

    case .functionCall(let functionCall):
      return type(of: functionCall, enclosingType: functionCall.identifier.enclosingType ?? enclosingType, callerCapabilities: callerCapabilities, scopeContext: scopeContext) ?? .errorType

    case .identifier(let identifier):
      if identifier.enclosingType == nil,
        let type = scopeContext.type(for: identifier.name) {
        if case .inoutType(let type) = type {
          return type
        }
        return type
      }
      return type(of: identifier.name, enclosingType: identifier.enclosingType ?? enclosingType, scopeContext: scopeContext)

    case .self(_): return .userDefinedType(enclosingType)
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.type.rawType
    case .subscriptExpression(let subscriptExpression):
      let identifierType = type(of: subscriptExpression.baseIdentifier.name, enclosingType: subscriptExpression.baseIdentifier.enclosingType ?? enclosingType, scopeContext: scopeContext)

      switch identifierType {
      case .arrayType(let elementType): return elementType
      case .fixedSizeArrayType(let elementType, _): return elementType
      case .dictionaryType(_, let valueType): return valueType
      default: fatalError()
      }
    case .literal(let literalToken): return type(ofLiteralToken: literalToken)
    case .arrayLiteral(let arrayLiteral):
      return type(ofArrayLiteral: arrayLiteral, enclosingType: enclosingType, scopeContext: scopeContext)
    case .dictionaryLiteral(let dictionaryLiteral):
      return type(ofDictionaryLiteral: dictionaryLiteral, enclosingType: enclosingType, scopeContext: scopeContext)
    case .sequence(_): fatalError()
    case .rawAssembly(_, let resultType): return resultType!
    }
  }

  /// The result of attempting to match a function call to its function declaration.
  ///
  /// - matchedFunction: A matching function declaration has been found.
  /// - matchedInitializer: A matching initializer declaration has been found
  /// - failure: The function declaration could not be found.
  public enum FunctionCallMatchResult {
    case matchedFunction(FunctionInformation)
    case matchedInitializer(InitializerInformation)
    case matchedGlobalFunction(FunctionInformation)
    case failure(candidates: [FunctionInformation])
  }

  /// Attempts to match a function call to its function declaration.
  ///
  /// - Parameters:
  ///   - functionCall: The function call for which to find its associated function declaration.
  ///   - enclosingType: The type in which the function should be declared.
  ///   - callerCapabilities: The caller capabilities associated with the function call.
  ///   - scopeContext: Contextual information about the scope in which the function call appears.
  /// - Returns: A `FunctionCallMatchResult`, either `success` or `failure`.
  public func matchFunctionCall(_ functionCall: FunctionCall, enclosingType: RawTypeIdentifier, callerCapabilities: [CallerCapability], scopeContext: ScopeContext) -> FunctionCallMatchResult {
    var candidates = [FunctionInformation]()

    var match: FunctionCallMatchResult? = nil
    
    let argumentIdentifiers = functionCall.arguments.map {
        $0.identifier
    }

    let argumentTypes = functionCall.arguments.map {
      type(of: $0.expression, enclosingType: enclosingType, scopeContext: scopeContext)
    }

    if let functions = types[enclosingType]?.functions[functionCall.identifier.name] {
      for candidate in functions {
        var identifiersMatch = (candidate.parameterIdentifiers.count == argumentIdentifiers.count)
        if identifiersMatch {
            for (index, identifier) in candidate.parameterIdentifiers.enumerated() {
                let matching = argumentIdentifiers[index] == nil || (argumentIdentifiers[index]!.identifierToken.kind == identifier.identifierToken.kind)
                if !matching {
                    identifiersMatch = matching
                    break
                }
            }
        }

        guard candidate.parameterTypes == argumentTypes,
          identifiersMatch,
          areCallerCapabilitiesCompatible(source: callerCapabilities, target: candidate.callerCapabilities) else {
            candidates.append(candidate)
            continue
        }

        match = .matchedFunction(candidate)
      }
    }

    if let initializers = types[functionCall.identifier.name]?.initializers {
      for candidate in initializers {
        guard candidate.parameterTypes == argumentTypes,
          areCallerCapabilitiesCompatible(source: callerCapabilities, target: candidate.callerCapabilities) else {
            // TODO: Add initializer candidates.
            continue
        }

        if match != nil {
          // This is an ambiguous call. There are too many matches.
          return .failure(candidates: [])
        }
        
        match = .matchedInitializer(candidate)
      }
    }

    // Check if it's a global function.

    if let functions = types[Environment.globalFunctionStructName]?.functions[functionCall.identifier.name] {
      for candidate in functions {

        guard candidate.parameterTypes == argumentTypes,
          areCallerCapabilitiesCompatible(source: callerCapabilities, target: candidate.callerCapabilities) else {
            candidates.append(candidate)
            continue
        }

        match = .matchedGlobalFunction(candidate)
      }
    }

    return match ?? .failure(candidates: candidates)
  }

  /// Set the public initializer for the given contract. A contract should have at most one public initializer.
  public mutating func setPublicInitializer(_ publicInitializer: InitializerDeclaration, forContract contract: RawTypeIdentifier) {
    types[contract]!.publicInitializer = publicInitializer
  }

  /// The public initializer for the given contract. A contract should have at most one public initializer.
  public func publicInitializer(forContract contract: RawTypeIdentifier) -> InitializerDeclaration? {
    return types[contract]!.publicInitializer
  }

  /// Whether two caller capability groups are compatible, i.e. whether a function with caller capabilities `source` is
  /// able to call a function which require caller capabilities `target`.
  func areCallerCapabilitiesCompatible(source: [CallerCapability], target: [CallerCapability]) -> Bool {
    guard !target.isEmpty else { return true }
    for callCallerCapability in source {
      if !target.contains(where: { return callCallerCapability.isSubcapability(callerCapability: $0) }) {
        return false
      }
    }
    return true
  }

  /// Associates a function call to an event call. Events are declared as properties in the contract's declaration.
  public func matchEventCall(_ functionCall: FunctionCall, enclosingType: RawTypeIdentifier) -> PropertyInformation? {
    let property = types[enclosingType]?.properties[functionCall.identifier.name]
    guard property?.rawType.isEventType ?? false, functionCall.arguments.count == property?.typeGenericArguments.count else { return nil }
    return property
  }


  /// The memory size of a type, in terms of number of memory slots it occupies.
  public func size(of type: Type.RawType) -> Int {
    switch type {
    case .basicType(.event): return 0 // Events do not use memory.
    case .basicType(_): return 1
    case .fixedSizeArrayType(let rawType, let elementCount): return size(of: rawType) * elementCount
    case .arrayType(_): return 1
    case .dictionaryType(_, _): return 1
    case .inoutType(_): fatalError()
    case .any: return 0
    case .errorType: return 0

    case .stdlibType(let type):
      return types[type.rawValue]!.properties.reduce(0) { acc, element in
        return acc + size(of: element.value.rawType)
      }
    case .userDefinedType(let identifier):
      return types[identifier]!.properties.reduce(0) { acc, element in
        return acc + size(of: element.value.rawType)
      }
    }
  }

  /// The memory offset of a property in a type.
  public func propertyOffset(for property: String, enclosingType: RawTypeIdentifier) -> Int? {
    var offsetMap = [String: Int]()
    var offset = 0

    let properties = types[enclosingType]!.orderedProperties.prefix(while: { $0 != property })

    for property in properties {
      offsetMap[property] = offset
      let propertyType = types[enclosingType]!.properties[property]!.rawType
      let propertySize = size(of: propertyType)

      offset += propertySize
    }

    return offset
  }
}

/// A table representing the memory offset of each property in a type.
struct OffsetTable {
  private var storage = [String: Int]()

  func offset(for propertyName: String) -> Int? {
    return storage[propertyName]
  }

  init(offsetMap: [String: Int]) {
    storage = offsetMap
  }
}

/// A list of properties and functions declared in a type.
public struct TypeInformation {
  var orderedProperties = [String]()
  var properties = [String: PropertyInformation]()
  var functions = [String: [FunctionInformation]]()
  var initializers = [InitializerInformation]()
  var publicInitializer: InitializerDeclaration? = nil
}

/// Information about a property defined in a type, such as its type and generic arguments.
public struct PropertyInformation {
  public var variableDeclaration: VariableDeclaration

  public var isConstant: Bool {
    return variableDeclaration.isConstant
  }

  public var isAssignedDefaultValue: Bool {
    return variableDeclaration.assignedExpression != nil
  }

  public var sourceLocation: SourceLocation? {
    return variableDeclaration.sourceLocation
  }

  init(variableDeclaration: VariableDeclaration) {
    self.variableDeclaration = variableDeclaration
  }

  public var rawType: Type.RawType {
    return variableDeclaration.type.rawType
  }

  public var typeGenericArguments: [Type.RawType] {
    return variableDeclaration.type.genericArguments.map { $0.rawType }
  }
}

/// Information about a function, such as which caller capabilities it requires and if it is mutating.
public struct FunctionInformation {
  public var declaration: FunctionDeclaration
  public var callerCapabilities: [CallerCapability]
  public var isMutating: Bool
  
  var parameterIdentifiers: [Identifier] {
      return declaration.parameters.map{ $0.identifier }
  }

  var parameterTypes: [Type.RawType] {
    return declaration.parameters.map { $0.type.rawType }
  }

  var resultType: Type.RawType? {
    return declaration.resultType?.rawType
  }
}

/// Information about an initializer.
public struct InitializerInformation {
  public var declaration: InitializerDeclaration
  public var callerCapabilities: [CallerCapability]

  var parameterTypes: [Type.RawType] {
    return declaration.parameters.map { $0.type.rawType }
  }
}
