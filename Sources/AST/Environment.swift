//
//  Environment.swift
//  AST
//
//  Created by Franklin Schrans on 12/26/17.
//

public struct Environment {
  var types = [RawTypeIdentifier: TypeInformation]()
  var offsets = [RawTypeIdentifier: OffsetTable]()
  var declaredContracts = [RawTypeIdentifier]()
  var declaredStructs = [RawTypeIdentifier]()

  public init() {}

  public mutating func addContract(_ contractDeclaration: ContractDeclaration) {
    declaredContracts.append(contractDeclaration.identifier.name)
    types[contractDeclaration.identifier.name] = TypeInformation()
    setProperties(contractDeclaration.variableDeclarations, enclosingType: contractDeclaration.identifier.name)
  }

  public mutating func addStruct(_ structDeclaration: StructDeclaration) {
    declaredStructs.append(structDeclaration.identifier.name)
    types[structDeclaration.identifier.name] = TypeInformation()
    setProperties(structDeclaration.variableDeclarations, enclosingType: structDeclaration.identifier.name)
    for functionDeclaration in structDeclaration.functionDeclarations {
      addFunction(functionDeclaration, enclosingType: structDeclaration.identifier.name)
    }
  }

  public mutating func addFunction(_ functionDeclaration: FunctionDeclaration, enclosingType: RawTypeIdentifier, callerCapabilities: [CallerCapability] = []) {
    let functionName = functionDeclaration.identifier.name

    types[enclosingType, default: TypeInformation()]
      .functions[functionName, default: [FunctionInformation]()]
      .append(FunctionInformation(declaration: functionDeclaration, callerCapabilities: callerCapabilities, isMutating: functionDeclaration.isMutating))
  }

  mutating func setProperties(_ variableDeclarations: [VariableDeclaration], enclosingType: RawTypeIdentifier) {
    types[enclosingType]!.orderedProperties = variableDeclarations.map { $0.identifier.name }
    for variableDeclaration in variableDeclarations {
      addProperty(variableDeclaration.identifier.name, type: variableDeclaration.type, enclosingType: enclosingType)
    }
  }

  mutating func addProperty(_ property: String, type: Type, enclosingType: RawTypeIdentifier) {
    types[enclosingType]!.properties[property] = PropertyInformation(type: type)
  }

  public mutating func addUsedUndefinedVariable(_ variable: Identifier, enclosingType: RawTypeIdentifier) {
    addProperty(variable.name, type: Type(inferredType: .errorType, identifier: variable), enclosingType: enclosingType)
  }

  public func isContractDeclared(_ type: RawTypeIdentifier) -> Bool {
    return declaredContracts.contains(type)
  }
  
  public func isStructDeclared(_ type: RawTypeIdentifier) -> Bool {
    return declaredStructs.contains(type)
  }
  
  public func isReferenceType(_ type: RawTypeIdentifier) -> Bool {
    return declaredStructs.contains(type) || declaredContracts.contains(type)
  }

  public func size(of type: Type.RawType) -> Int {
    switch type {
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

  public func isPropertyDefined(_ property: String, enclosingType: RawTypeIdentifier) -> Bool {
    return types[enclosingType]!.properties.keys.contains(property)
  }

  public func properties(in enclosingType: RawTypeIdentifier) -> [String] {
    return types[enclosingType]!.orderedProperties
  }

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

  public func containsCallerCapability(_ callerCapability: CallerCapability, enclosingType: RawTypeIdentifier) -> Bool {
    return declaredCallerCapabilities(enclosingType: enclosingType).contains(callerCapability.name)
  }

  public func type(of property: String, enclosingType: RawTypeIdentifier, scopeContext: ScopeContext? = nil) -> Type.RawType? {
    if let type = types[enclosingType]?.properties[property]?.rawType {
      return type
    }
    
    guard let scopeContext = scopeContext, let type = scopeContext.type(for: property) else { fatalError() }
    return type
  }

  public func type(of functionCall: FunctionCall, enclosingType: RawTypeIdentifier, callerCapabilities: [CallerCapability], scopeContext: ScopeContext) -> Type.RawType? {
    guard case .success(let matchingFunction) = matchFunctionCall(functionCall, enclosingType: enclosingType, callerCapabilities: callerCapabilities, scopeContext: scopeContext) else { return .errorType }
    return matchingFunction.resultType
  }

  public func type(of expression: Expression, functionDeclarationContext: FunctionDeclarationContext? = nil, enclosingType: RawTypeIdentifier, callerCapabilities: [CallerCapability] = [], scopeContext: ScopeContext) -> Type.RawType {
    switch expression {
    case .inoutExpression(let inoutExpression):
      return .inoutType(type(of: inoutExpression.expression, functionDeclarationContext: functionDeclarationContext, enclosingType: enclosingType, callerCapabilities: callerCapabilities, scopeContext: scopeContext))
    case .binaryExpression(let binaryExpression):
      if binaryExpression.opToken.isBooleanOperator {
        return .builtInType(.bool)
      }
      return type(of: binaryExpression.rhs, functionDeclarationContext: functionDeclarationContext, enclosingType: enclosingType, callerCapabilities: callerCapabilities, scopeContext: scopeContext)

    case .bracketedExpression(let expression):
      return type(of: expression, functionDeclarationContext: functionDeclarationContext, enclosingType: enclosingType, callerCapabilities: callerCapabilities, scopeContext: scopeContext)

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

    case .literal(let token):
      guard case .literal(let literal) = token.kind else { fatalError() }
      switch literal {
      case .boolean(_): return .builtInType(.bool)
      case .decimal(.integer(_)): return .builtInType(.int)
      case .string(_): return .builtInType(.string)
      default: fatalError()
      }
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
    }
  }

  public enum FunctionCallMatchResult {
    case success(FunctionInformation)
    case failure(candidates: [FunctionInformation])
  }

  public func matchFunctionCall(_ functionCall: FunctionCall, enclosingType: RawTypeIdentifier, callerCapabilities: [CallerCapability], scopeContext: ScopeContext) -> FunctionCallMatchResult {
    var candidates = [FunctionInformation]()

    for candidate in types[enclosingType]!.functions[functionCall.identifier.name]! {
      let argumentTypes = functionCall.arguments.map { type(of: $0, enclosingType: enclosingType, scopeContext: scopeContext) }

      guard candidate.parameterTypes == argumentTypes,
        areCallerCapabilitiesCompatible(source: callerCapabilities, target: candidate.callerCapabilities) else {
          candidates.append(candidate)
          continue
      }

      return .success(candidate)
    }

    return .failure(candidates: candidates)
  }

  func areCallerCapabilitiesCompatible(source: [CallerCapability], target: [CallerCapability]) -> Bool {
    guard !target.isEmpty else { return true }
    for callCallerCapability in source {
      if !target.contains(where: { return callCallerCapability.isSubcapability(callerCapability: $0) }) {
        return false
      }
    }
    return true
  }

  public func matchEventCall(_ functionCall: FunctionCall, enclosingType: RawTypeIdentifier) -> PropertyInformation? {
    let property = types[enclosingType]?.properties[functionCall.identifier.name]
    guard property?.rawType.isEventType ?? false, functionCall.arguments.count == property?.typeGenericArguments.count else { return nil }
    return property
  }
}

struct OffsetTable {
  private var storage = [String: Int]()

  func offset(for propertyName: String) -> Int? {
    return storage[propertyName]
  }

  init(offsetMap: [String: Int]) {
    storage = offsetMap
  }
}

public struct TypeInformation {
  var orderedProperties = [String]()
  var properties = [String: PropertyInformation]()
  var functions = [String: [FunctionInformation]]()
}

public struct PropertyInformation {
  private var type: Type

  init(type: Type) {
    self.type = type
  }

  public var rawType: Type.RawType {
    return type.rawType
  }

  public var typeGenericArguments: [Type.RawType] {
    return type.genericArguments.map { $0.rawType }
  }
}

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
