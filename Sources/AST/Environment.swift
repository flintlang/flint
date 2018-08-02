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

  /// A list of the names of the enums which have been declared in the program.
  var declaredEnums = [Identifier]()


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
    setProperties(contractDeclaration.variableDeclarations.map{ .variableDeclaration($0) }, enclosingType: contractDeclaration.identifier.name)
  }

  /// Add a struct declaration to the environment.
  public mutating func addStruct(_ structDeclaration: StructDeclaration) {
    declaredStructs.append(structDeclaration.identifier)
    if types[structDeclaration.identifier.name] == nil {
      types[structDeclaration.identifier.name] = TypeInformation()
    }
    setProperties(structDeclaration.variableDeclarations.map{ .variableDeclaration($0) }, enclosingType: structDeclaration.identifier.name)
    for functionDeclaration in structDeclaration.functionDeclarations {
      addFunction(functionDeclaration, enclosingType: structDeclaration.identifier.name)
    }
  }

  /// Add an enum declaration to the environment.
  public mutating func addEnum(_ enumDeclaration: EnumDeclaration) {
    declaredEnums.append(enumDeclaration.identifier)
    if types[enumDeclaration.identifier.name] == nil {
      types[enumDeclaration.identifier.name] = TypeInformation()
    }
    setProperties(enumDeclaration.cases.map{ .enumCase($0) }, enclosingType: enumDeclaration.identifier.name)
  }

  /// Add a function declaration to a type (contract or struct). In the case of a contract, a list of caller
  /// capabilities is expected.
  public mutating func addFunction(_ functionDeclaration: FunctionDeclaration, enclosingType: RawTypeIdentifier, typeStates: [TypeState] = [], callerCapabilities: [CallerCapability] = []) {
    let functionName = functionDeclaration.identifier.name

    types[enclosingType, default: TypeInformation()]
      .functions[functionName, default: [FunctionInformation]()]
      .append(FunctionInformation(declaration: functionDeclaration, typeStates: typeStates, callerCapabilities: callerCapabilities, isMutating: functionDeclaration.isMutating))
  }

  /// Add an initializer declaration to a type (contract or struct). In the case of a contract, a list of caller
  /// capabilities is expected.
  public mutating func addInitializer(_ initializerDeclaration: InitializerDeclaration, enclosingType: RawTypeIdentifier, callerCapabilities: [CallerCapability] = []) {
    types[enclosingType, default: TypeInformation()].initializers.append(InitializerInformation(declaration: initializerDeclaration, callerCapabilities: callerCapabilities))
  }

  /// Add a list of properties to a type.
  mutating func setProperties(_ properties: [Property], enclosingType: RawTypeIdentifier) {
    types[enclosingType]!.orderedProperties = properties.map { $0.identifier.name }
    for property in properties {
      addProperty(property, enclosingType: enclosingType)
    }
  }

  /// Add a property to a type.
  mutating func addProperty(_ property: Property, enclosingType: RawTypeIdentifier) {
    if types[enclosingType]!.properties[property.identifier.name] == nil {
      types[enclosingType]!.properties[property.identifier.name] = PropertyInformation(property: property)
    }
  }

  /// Add a use of an undefined variable.
  public mutating func addUsedUndefinedVariable(_ variable: Identifier, enclosingType: RawTypeIdentifier) {
    let declaration = VariableDeclaration(declarationToken: nil, identifier: variable, type: Type(inferredType: .errorType, identifier: variable))
    addProperty(.variableDeclaration(declaration), enclosingType: enclosingType)
  }

  /// Whether a contract has been declared in the program.
  public func isContractDeclared(_ type: RawTypeIdentifier) -> Bool {
    return declaredContracts.contains { $0.name == type }
  }

  // Whether any contract has been declared in the program.
  public func hasDeclaredContract() -> Bool {
    return !declaredContracts.isEmpty
  }

  /// Whether a struct has been declared in the program.
  public func isStructDeclared(_ type: RawTypeIdentifier) -> Bool {
    return declaredStructs.contains { $0.name == type }
  }

  /// Whether an enum has been declared in the program.
  public func isEnumDeclared(_ type: RawTypeIdentifier) -> Bool {
    return declaredEnums.contains { $0.name == type }
  }

  /// Whether a type has been declared in the program.
  public func isTypeDeclared(_ type: RawTypeIdentifier) -> Bool {
      return types[type] != nil
  }

  public func isStateful(_ contract: RawTypeIdentifier) -> Bool {
    let enumName = ContractDeclaration.contractEnumPrefix + contract
    return declaredEnums.contains(where: { $0.name == enumName })
  }

  /// Whether a state has been declared in this contract.
  public func isStateDeclared(_ state: Identifier, in contract: RawTypeIdentifier) -> Bool {
    let enumName = ContractDeclaration.contractEnumPrefix + contract
    return types[enumName]?.properties[state.name] != nil
  }

  /// Whether a struct is self referencing.
  public func selfReferentialProperty(in type: RawTypeIdentifier, enclosingType: RawTypeIdentifier) -> PropertyInformation? {
    guard let enclosingMemberTypes = types[enclosingType] else { return nil }

    for member in enclosingMemberTypes.orderedProperties {
      guard let memberType = enclosingMemberTypes.properties[member]?.rawType.name else { return nil }
      if memberType == type {
        return enclosingMemberTypes.properties[member]
      }
      if let member = selfReferentialProperty(in: type, enclosingType: memberType) {
        return member
      }
    }
    return nil
  }

  /// Whether a function call refers to an initializer.
  public func isInitializerCall(_ functionCall: FunctionCall) -> Bool {
    return isStructDeclared(functionCall.identifier.name)
  }

  /// Whether a property is defined in a type.
  public func isPropertyDefined(_ identifier: String, enclosingType: RawTypeIdentifier) -> Bool {
    return property(identifier, enclosingType) != nil
  }

  public func property(_ identifier: String, _ enclosingType: RawTypeIdentifier) -> PropertyInformation? {
    return types[enclosingType]?.properties[identifier]
  }

  /// Whether is property is declared as a constant.
  public func isPropertyConstant(_ identifier: String, enclosingType: RawTypeIdentifier) -> Bool {
    return property(identifier, enclosingType)!.isConstant
  }

  public func isPropertyAssignedDefaultValue(_ identifier: String, enclosingType: RawTypeIdentifier) -> Bool {
    return property(identifier, enclosingType)!.isAssignedDefaultValue
  }

  /// The source location of a property declaration.
  public func propertyDeclarationSourceLocation(_ identifier: String, enclosingType: RawTypeIdentifier) -> SourceLocation? {
    return property(identifier, enclosingType)!.sourceLocation
  }

  /// The names of the properties declared in a type.
  public func properties(in enclosingType: RawTypeIdentifier) -> [String] {
    return types[enclosingType]!.orderedProperties
  }

  /// The list of property declarations in a type.
  public func propertyDeclarations(in enclosingType: RawTypeIdentifier) -> [Property] {
    return types[enclosingType]!.properties.values.map { $0.property }
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
    return conflictingDeclaration(of: type, in: declaredStructs + declaredContracts + declaredEnums)
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
  public func type(of functionCall: FunctionCall, enclosingType: RawTypeIdentifier, typeStates: [TypeState], callerCapabilities: [CallerCapability], scopeContext: ScopeContext) -> Type.RawType? {
    let match = matchFunctionCall(functionCall, enclosingType: enclosingType, typeStates: typeStates, callerCapabilities: callerCapabilities, scopeContext: scopeContext)

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
    case .address(_): return .basicType(.address)
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

  // The type of a range.
  public func type(ofRangeExpression rangeExpression: RangeExpression, enclosingType: RawTypeIdentifier, scopeContext: ScopeContext) -> Type.RawType {
    let elementType = type(of: rangeExpression.initial, enclosingType: enclosingType, scopeContext: scopeContext)
    let boundType   = type(of: rangeExpression.bound, enclosingType: enclosingType, scopeContext: scopeContext)

    if elementType != boundType {
      // The bounds have different types.
      return .errorType
    }

    return .rangeType(elementType)
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
  public func type(of expression: Expression, enclosingType: RawTypeIdentifier, typeStates: [TypeState] = [], callerCapabilities: [CallerCapability] = [], scopeContext: ScopeContext) -> Type.RawType {

    switch expression {
    case .inoutExpression(let inoutExpression):
      return .inoutType(type(of: inoutExpression.expression, enclosingType: enclosingType, typeStates: typeStates, callerCapabilities: callerCapabilities, scopeContext: scopeContext))
    case .binaryExpression(let binaryExpression):
      if binaryExpression.opToken.isBooleanOperator {
        return .basicType(.bool)
      }
      return type(of: binaryExpression.rhs, enclosingType: enclosingType, typeStates: typeStates, callerCapabilities: callerCapabilities, scopeContext: scopeContext)

    case .bracketedExpression(let expression):
      return type(of: expression, enclosingType: enclosingType, typeStates: typeStates, callerCapabilities: callerCapabilities, scopeContext: scopeContext)

    case .functionCall(let functionCall):
      return type(of: functionCall, enclosingType: functionCall.identifier.enclosingType ?? enclosingType, typeStates: typeStates, callerCapabilities: callerCapabilities, scopeContext: scopeContext) ?? .errorType

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
      let identifierType = type(of: subscriptExpression.baseExpression, enclosingType: enclosingType, scopeContext: scopeContext)

      switch identifierType {
      case .arrayType(let elementType): return elementType
      case .fixedSizeArrayType(let elementType, _): return elementType
      case .dictionaryType(_, let valueType): return valueType
      default: fatalError()
      }
    case .literal(let literalToken): return type(ofLiteralToken: literalToken)
    case .arrayLiteral(let arrayLiteral):
      return type(ofArrayLiteral: arrayLiteral, enclosingType: enclosingType, scopeContext: scopeContext)
    case .range(let rangeExpression):
      return type(ofRangeExpression: rangeExpression, enclosingType: enclosingType, scopeContext: scopeContext)
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
  public func matchFunctionCall(_ functionCall: FunctionCall, enclosingType: RawTypeIdentifier, typeStates: [TypeState], callerCapabilities: [CallerCapability], scopeContext: ScopeContext) -> FunctionCallMatchResult {
    var candidates = [FunctionInformation]()

    var match: FunctionCallMatchResult? = nil

    let argumentTypes = functionCall.arguments.map {
      type(of: $0, enclosingType: enclosingType, scopeContext: scopeContext)
    }

    if let functions = types[enclosingType]?.functions[functionCall.identifier.name] {
      for candidate in functions {
        guard candidate.parameterTypes == argumentTypes,
          areCallerCapabilitiesCompatible(source: callerCapabilities, target: candidate.callerCapabilities),
          areTypeStatesCompatible(source: typeStates, target: candidate.typeStates) else {
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
      if !target.contains(where: { return callCallerCapability.isSubCapability(of: $0) }) {
        return false
      }
    }
    return true
  }

  /// Whether two type state groups are compatible, i.e. whether a function with
  /// type states `source` is able to call a function requiring 'target' states.
  func areTypeStatesCompatible(source: [TypeState], target: [TypeState]) -> Bool {
    guard !target.isEmpty else { return true }
    for callTypeState in source {
      if !target.contains(where: { return callTypeState.isSubState(of: $0) }) {
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
    case .rangeType(_): return 0 // Ranges do not use memory
    case .dictionaryType(_, _): return 1
    case .inoutType(_): fatalError()
    case .any: return 0
    case .errorType: return 0

    case .stdlibType(let type):
      return types[type.rawValue]!.properties.reduce(0) { acc, element in
        return acc + size(of: element.value.rawType)
      }
    case .userDefinedType(let identifier):
      if isEnumDeclared(identifier),
        case .enumCase(let enumCase) = types[identifier]!.properties.first!.value.property{
        return size(of: enumCase.hiddenType.rawType)
      }
      return types[identifier]!.properties.reduce(0) { acc, element in
        return acc + size(of: element.value.rawType)
      }
    }
  }

  /// The memory offset of a property in a type.
  public func propertyOffset(for property: String, enclosingType: RawTypeIdentifier) -> Int? {

    var offsetMap = [String: Int]()
    var offset = 0

    let rootType = types[enclosingType]!

    for p in rootType.orderedProperties.prefix(while: { $0 != property }) {
      offsetMap[p] = offset
      let propertyType = rootType.properties[p]!.rawType
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

public enum Property {
  case variableDeclaration(VariableDeclaration)
  case enumCase(EnumCase)

  public var identifier: Identifier {
    switch self {
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.identifier
    case .enumCase(let enumCase):
      return enumCase.identifier
    }
  }

  public var value: Expression? {
    switch self {
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.assignedExpression
    case .enumCase(let enumCase):
      return enumCase.hiddenValue
    }
  }

  public var type: Type? {
    switch self {
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.type
    case .enumCase(let enumCase):
      return enumCase.type
    }
  }

  public var sourceLocation: SourceLocation {
    switch self {
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.sourceLocation
    case .enumCase(let enumCase):
      return enumCase.sourceLocation
    }
  }
}

/// Information about a property defined in a type, such as its type and generic arguments.
public struct PropertyInformation {
  public var property: Property

  public var isConstant: Bool {
    switch property {
      case .variableDeclaration(let variableDeclaration): return variableDeclaration.isConstant
      case .enumCase(_): return true
    }
  }

  public var isAssignedDefaultValue: Bool {
    switch property {
      case .variableDeclaration(let variableDeclaration):
        return variableDeclaration.assignedExpression != nil
      case .enumCase(let enumCase):
        return enumCase.hiddenValue != nil
    }
  }

  public var sourceLocation: SourceLocation? {
    switch property {
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.sourceLocation
    case .enumCase(let enumCase):
      return enumCase.sourceLocation
    }
  }

  public var rawType: Type.RawType {
    return property.type!.rawType
  }

  public var typeGenericArguments: [Type.RawType] {
    switch property {
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.type.genericArguments.map { $0.rawType }
    case .enumCase(_):
      return []
    }
  }
}

/// Information about a function, such as which caller capabilities it requires and if it is mutating.
public struct FunctionInformation {
  public var declaration: FunctionDeclaration
  public var typeStates: [TypeState]
  public var callerCapabilities: [CallerCapability]
  public var isMutating: Bool

  var parameterTypes: [Type.RawType] {
    return declaration.parameters.map { $0.type.rawType }
  }

  var resultType: Type.RawType? {
    return declaration.resultType?.rawType
  }
}

/// Informatino about an initializer.
public struct InitializerInformation {
  public var declaration: InitializerDeclaration
  public var callerCapabilities: [CallerCapability]

  var parameterTypes: [Type.RawType] {
    return declaration.parameters.map { $0.type.rawType }
  }
}
