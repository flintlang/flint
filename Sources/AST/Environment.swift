//
//  Environment.swift
//  AST
//
//  Created by Franklin Schrans on 12/26/17.
//

/// Information about the source program.
public struct Environment {
  /// Information abbout each type (contracts and structs) which the program define, such as its properties and
  /// functions.
  var types = [RawTypeIdentifier: TypeInformation]()

  /// The offset tables used to represent each type at runtime.
  var offsets = [RawTypeIdentifier: OffsetTable]()

  /// A list of the names of the contracts which have been declared in the program.
  var declaredContracts = [RawTypeIdentifier]()

  /// A list of the names of the structs which have been declared in the program.
  var declaredStructs = [RawTypeIdentifier]()

  public init() {}

  /// Add a contract declaration to the environment.
  public mutating func addContract(_ contractDeclaration: ContractDeclaration) {
    declaredContracts.append(contractDeclaration.identifier.name)
    types[contractDeclaration.identifier.name] = TypeInformation()
    setProperties(contractDeclaration.variableDeclarations, enclosingType: contractDeclaration.identifier.name)
  }

  /// Add a struct declaration to the environment.
  public mutating func addStruct(_ structDeclaration: StructDeclaration) {
    declaredStructs.append(structDeclaration.identifier.name)
    types[structDeclaration.identifier.name] = TypeInformation()
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

  /// Add a list of properties to a type.
  mutating func setProperties(_ variableDeclarations: [VariableDeclaration], enclosingType: RawTypeIdentifier) {
    types[enclosingType]!.orderedProperties = variableDeclarations.map { $0.identifier.name }
    for variableDeclaration in variableDeclarations {
      addProperty(variableDeclaration.identifier.name, type: variableDeclaration.type, isConstant: variableDeclaration.isConstant, sourceLocation: variableDeclaration.sourceLocation, enclosingType: enclosingType)
    }
  }

  /// Add a property to a type.
  mutating func addProperty(_ property: String, type: Type, isConstant: Bool = false, sourceLocation: SourceLocation?, enclosingType: RawTypeIdentifier) {
    types[enclosingType]!.properties[property] = PropertyInformation(type: type, isConstant: isConstant, sourceLocation: sourceLocation)
  }

  /// Add a use of an undefined variable.
  public mutating func addUsedUndefinedVariable(_ variable: Identifier, enclosingType: RawTypeIdentifier) {
    addProperty(variable.name, type: Type(inferredType: .errorType, identifier: variable), sourceLocation: nil, enclosingType: enclosingType)
  }

  /// Whether a contract has been declared in the program.
  public func isContractDeclared(_ type: RawTypeIdentifier) -> Bool {
    return declaredContracts.contains(type)
  }

  /// Whether a struct has been declared in the program.
  public func isStructDeclared(_ type: RawTypeIdentifier) -> Bool {
    return declaredStructs.contains(type)
  }
  
  /// Whether the given type is a reference type (a contract).
  public func isReferenceType(_ type: RawTypeIdentifier) -> Bool {
    // TODO: it should be possible to pass structs by value as well.
    return declaredStructs.contains(type) || declaredContracts.contains(type)
  }

  /// Whether a property is defined in a type.
  public func isPropertyDefined(_ property: String, enclosingType: RawTypeIdentifier) -> Bool {
    return types[enclosingType]!.properties.keys.contains(property)
  }

  /// Whether is property is declared as a constnat.
  public func isPropertyConstant(_ property: String, enclosingType: RawTypeIdentifier) -> Bool {
    return types[enclosingType]!.properties[property]!.isConstant
  }

  public func propertyDeclarationSourceLocation(_ property: String, enclosingType: RawTypeIdentifier) -> SourceLocation? {
    return types[enclosingType]!.properties[property]!.sourceLocation
  }

  /// The list of properties declared in a type.
  public func properties(in enclosingType: RawTypeIdentifier) -> [String] {
    return types[enclosingType]!.orderedProperties
  }

  /// The list of properties declared in a type which can be used as caller capabilities.
  func declaredCallerCapabilities(enclosingType: RawTypeIdentifier) -> [String] {
    return types[enclosingType]!.properties.compactMap { key, value in
      switch value.rawType {
      case .builtInType(.address): return key
      case .fixedSizeArrayType(.builtInType(.address), _): return key
      case .arrayType(.builtInType(.address)): return key
      default: return nil
      }
    }
  }

  /// Whether the given caller capability is declared in the given type.
  public func containsCallerCapability(_ callerCapability: CallerCapability, enclosingType: RawTypeIdentifier) -> Bool {
    return declaredCallerCapabilities(enclosingType: enclosingType).contains(callerCapability.name)
  }

  /// The type of a property in the given enclosing type or in a scope if it is a local variable.
  public func type(of property: String, enclosingType: RawTypeIdentifier, scopeContext: ScopeContext? = nil) -> Type.RawType? {
    if let type = types[enclosingType]?.properties[property]?.rawType {
      return type
    }
    
    guard let scopeContext = scopeContext, let type = scopeContext.type(for: property) else { fatalError() }
    return type
  }

  /// The type return type of a function call, determined by looking up the function's declaration.
  public func type(of functionCall: FunctionCall, enclosingType: RawTypeIdentifier, callerCapabilities: [CallerCapability], scopeContext: ScopeContext) -> Type.RawType? {
    guard case .success(let matchingFunction) = matchFunctionCall(functionCall, enclosingType: enclosingType, callerCapabilities: callerCapabilities, scopeContext: scopeContext) else { return .errorType }
    return matchingFunction.resultType
  }

  public func type(ofLiteralToken literalToken: Token) -> Type.RawType {
    guard case .literal(let literal) = literalToken.kind else { fatalError() }
    switch literal {
    case .boolean(_): return .builtInType(.bool)
    case .decimal(.integer(_)): return .builtInType(.int)
    case .string(_): return .builtInType(.string)
    default: fatalError()
    }
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
        return .builtInType(.bool)
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
      return type(of: identifier.name, enclosingType: identifier.enclosingType ?? enclosingType, scopeContext: scopeContext)!

    case .self(_): return .userDefinedType(enclosingType)
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.type.rawType
    case .subscriptExpression(let subscriptExpression):
      let identifierType = type(of: subscriptExpression.baseIdentifier.name, enclosingType: subscriptExpression.baseIdentifier.enclosingType ?? enclosingType, scopeContext: scopeContext)!

      switch identifierType {
      case .arrayType(let elementType): return elementType
      case .fixedSizeArrayType(let elementType, _): return elementType
      case .dictionaryType(_, let valueType): return valueType
      default: fatalError()
      }
    case .literal(let literalToken): return type(ofLiteralToken: literalToken)
    }
  }

  /// The result of attempting to match a function call to its function declaration.
  ///
  /// - success: The function declaration has been found.
  /// - failure: The function declaration could not be found.
  public enum FunctionCallMatchResult {
    case success(FunctionInformation)
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

    if let functions = types[enclosingType]!.functions[functionCall.identifier.name] {
      for candidate in functions {
        let argumentTypes = functionCall.arguments.map { type(of: $0, enclosingType: enclosingType, scopeContext: scopeContext) }

        guard candidate.parameterTypes == argumentTypes,
          areCallerCapabilitiesCompatible(source: callerCapabilities, target: candidate.callerCapabilities) else {
            candidates.append(candidate)
            continue
        }

        return .success(candidate)
      }
    }

    return .failure(candidates: candidates)
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
    case .builtInType(.event): return 0 // Events do not use memory.
    case .builtInType(_): return 1
    case .fixedSizeArrayType(let rawType, let elementCount): return size(of: rawType) * elementCount
    case .arrayType(_): return 1
    case .dictionaryType(_, _): return 1
    case .inoutType(_): fatalError()
    case .errorType: return 0

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
  var publicInitializer: InitializerDeclaration? = nil
}

/// Information about a property defined in a type, such as its type and generic arguments.
public struct PropertyInformation {
  private var type: Type

  public var isConstant: Bool
  public var sourceLocation: SourceLocation?

  init(type: Type, isConstant: Bool = false, sourceLocation: SourceLocation?) {
    self.type = type
    self.isConstant = isConstant
    self.sourceLocation = sourceLocation
  }

  public var rawType: Type.RawType {
    return type.rawType
  }

  public var typeGenericArguments: [Type.RawType] {
    return type.genericArguments.map { $0.rawType }
  }
}

/// Information about a function, such as which caller capabilities it requires and if it is mutating.
public struct FunctionInformation {
  public var declaration: FunctionDeclaration
  public var callerCapabilities: [CallerCapability]
  public var isMutating: Bool

  var parameterTypes: [Type.RawType] {
    return declaration.parameters.map { $0.type.rawType }
  }

  var resultType: Type.RawType? {
    return declaration.resultType?.rawType
  }
}
