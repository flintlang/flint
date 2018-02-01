//
//  Environment.swift
//  AST
//
//  Created by Franklin Schrans on 12/26/17.
//

public struct Environment {
//  var contractDeclarations = [ContractDeclaration]()
//  var functions = [MangledFunction]()

//  var typeUndefinedVariables = [Identifier: [Identifier]]()

//  public var declaredContractsIdentifiers: [Identifier] {
//    return contractDeclarations.map { $0.identifier }
//  }

//  var typeLayoutMap = [String: TypeLayout]()

  var types = [RawTypeIdentifier: TypeInformation]()
  var offsets = [RawTypeIdentifier: OffsetTable]()

  public init() {}

  public mutating func addContract(_ contractDeclaration: ContractDeclaration) {
    types[contractDeclaration.identifier.name] = TypeInformation(kind: .contract)
    setProperties(contractDeclaration.variableDeclarations, enclosingType: contractDeclaration.identifier.name)
  }

  public mutating func addStruct(_ structDeclaration: StructDeclaration) {
    types[structDeclaration.identifier.name] = TypeInformation(kind: .struct)
    setProperties(structDeclaration.variableDeclarations, enclosingType: structDeclaration.identifier.name)
    for functionDeclaration in structDeclaration.functionDeclarations {
      addFunction(functionDeclaration, enclosingType: structDeclaration.identifier.name, enclosingKind: .struct)
    }
  }

  public mutating func addFunction(_ functionDeclaration: FunctionDeclaration, enclosingType: RawTypeIdentifier, enclosingKind: TypeInformation.Kind = .contract, callerCapabilities: [CallerCapability] = []) {
    let functionName = functionDeclaration.identifier.name

    types[enclosingType, default: TypeInformation(kind: enclosingKind)]
      .functions[functionName, default: [FunctionInformation]()]
      .append(FunctionInformation(declaration: functionDeclaration, callerCapabilities: callerCapabilities, isMutating: functionDeclaration.isMutating))
  }

  mutating func setProperties(_ variableDeclarations: [VariableDeclaration], enclosingType: RawTypeIdentifier) {
    for variableDeclaration in variableDeclarations {
      addProperty(variableDeclaration.identifier.name, type: variableDeclaration.type, enclosingType: enclosingType)
    }

    var offsetMap = [String: Int]()
    var offset = 0

    for variableDeclaration in variableDeclarations {
      let propertyIdentifier = variableDeclaration.identifier
      offsetMap[propertyIdentifier.name] = offset

      let propertyType = variableDeclaration.type.rawType
      let propertySize = size(of: propertyType)

      offset += propertySize
    }

    offsets[enclosingType] = OffsetTable(offsetMap: offsetMap)
  }

  mutating func addProperty(_ property: String, type: Type, enclosingType: RawTypeIdentifier) {
    types[enclosingType]!.properties[property] = PropertyInformation(type: type)
  }

  public mutating func addUsedUndefinedVariable(_ variable: Identifier, enclosingType: RawTypeIdentifier) {
    addProperty(variable.name, type: Type(inferredType: .errorType, identifier: variable), enclosingType: enclosingType)
  }

//  public mutating func addContract(_ contractDeclaration: ContractDeclaration) {
//    contractDeclarations.append(contractDeclaration)
//    addVariableDeclarations(contractDeclaration.variableDeclarations, enclosingType: contractDeclaration.identifier)
//  }

//  public mutating func addStruct(_ structDeclaration: StructDeclaration) {
////    structDeclarations.append(structDeclaration)
//    addVariableDeclarations(structDeclaration.variableDeclarations, enclosingType: structDeclaration.identifier)
//  }

  public func isDeclaredContract(_ type: RawTypeIdentifier) -> Bool {
    guard let kind = types[type]?.kind, case .contract = kind else { return false }
    return true
  }

  public func size(of type: Type.RawType) -> Int {
    switch type {
    case .builtInType(_): return 1
    case .fixedSizeArrayType(let rawType, let elementCount): return size(of: rawType) * elementCount
    case .arrayType(_): return 1
    case .dictionaryType(_, _): return 1
    case .errorType: return 0

    case .userDefinedType(let identifier):
//      let propertyDeclarations = properties(declaredIn: identifier)
//      return propertyDeclarations.reduce(0, { acc, element in
//        return acc + size(of: element.type.rawType)
//      })
      return types[identifier]!.properties.reduce(0) { acc, element in
        return acc + size(of: element.value.rawType)
      }
    }
  }

//  func matchStruct(identifier: Identifier) -> StructDeclaration? {
//    return structDeclarations.first(where: { $0.identifier == identifier })
//  }

//  public func properties(declaredIn type: String) -> [String: PropertyInformation]? {
//    if let contractDeclaration = contractDeclarations.first(where: { $0.identifier == type }) {
//      return contractDeclaration.variableDeclarations
//    }
//
//    if let structDeclaration = matchStruct(identifier: type) {
//      return structDeclaration.variableDeclarations
//    }
//    return []
//
//    return types[type]?.properties
//  }

  public func propertyOffset(for property: String, enclosingType: RawTypeIdentifier) -> Int? {
//    return typeLayoutMap[type]?.offset(for: property)
    return offsets[enclosingType]?.offset(for: property)
  }

  public func propertyIsDefined(_ property: String, enclosingType: RawTypeIdentifier) -> Bool {
//    return typeLayoutMap[type]?.contains(property) ?? false
    return types[enclosingType]!.properties.keys.contains(property)
  }

  func declaredCallerCapabilities(enclosingType: RawTypeIdentifier) -> [String] {
//    let contractDefinitionIdentifier = declaredContractsIdentifiers.first { $0.name == contractIdentifier.name }!
//    let variables = properties(declaredIn: contractDefinitionIdentifier)
//    return variables.filter { variable in
//      switch variable.type.rawType {
//      case .builtInType(.address): return true
//      case .fixedSizeArrayType(.builtInType(.address), _): return true
//      case .arrayType(let rawType): return rawType == .builtInType(.address)
//      default: return false
//      }
//    }

    return types[enclosingType]!.properties.flatMap { key, value in
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

  public func type(of property: String, enclosingType: RawTypeIdentifier) -> Type.RawType? {
//    if typeUndefinedVariables[typeIdentifier, default: []].contains(identifier) {
//      return .errorType
//    }
//    let mangledIdentifier = identifier.mangled(in: typeIdentifier)
//    return typeMap[mangledIdentifier]
    return types[enclosingType]?.properties[property]?.rawType
  }

  public func type(of functionCall: FunctionCall, enclosingType: RawTypeIdentifier, callerCapabilities: [CallerCapability]) -> Type.RawType? {
    guard case .success(let matchingFunction) = matchFunctionCall(functionCall, enclosingType: enclosingType, callerCapabilities: callerCapabilities) else { return .errorType }
    return matchingFunction.resultType
  }

  public func type(of expression: Expression, functionDeclarationContext: FunctionDeclarationContext? = nil, enclosingType: RawTypeIdentifier, callerCapabilities: [CallerCapability] = []) -> Type.RawType {
    switch expression {
    case .binaryExpression(let binaryExpression):
      return type(of: binaryExpression.rhs, functionDeclarationContext: functionDeclarationContext, enclosingType: enclosingType, callerCapabilities: callerCapabilities)

    case .bracketedExpression(let expression):
      return type(of: expression, functionDeclarationContext: functionDeclarationContext, enclosingType: enclosingType, callerCapabilities: callerCapabilities)

    case .functionCall(let functionCall):
      return type(of: functionCall, enclosingType: enclosingType, callerCapabilities: callerCapabilities) ?? .errorType

    case .identifier(let identifier):
      if identifier.enclosingType == nil,
        let functionDeclarationContext = functionDeclarationContext,
        let localVariable = functionDeclarationContext.declaration.matchingLocalVariable(identifier) {
        return localVariable.type.rawType
      }
      return type(of: identifier.name, enclosingType: enclosingType)!

    case .literal(let token):
      guard case .literal(let literal) = token.kind else { fatalError() }
      switch literal {
      case .boolean(_): return .builtInType(.bool)
      case .decimal(.integer(_)): return .builtInType(.int)
      default: fatalError()
      }
    case .self(_): return .userDefinedType(enclosingType)
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.type.rawType
    case .subscriptExpression(let subscriptExpression):
      let identifierType = type(of: subscriptExpression.baseIdentifier.name, enclosingType: enclosingType)!

      switch identifierType {
      case .arrayType(let elementType): return elementType
      case .fixedSizeArrayType(let elementType, _): return elementType
      case .dictionaryType(_, let valueType): return valueType
      default: fatalError()
      }
    }
  }

//  public mutating func setType(of identifier: Identifier, enclosingType: RawTypeIdentifier, type: Type) {
//    let mangledIdentifier = identifier.mangled(in: contractIdentifier)
//    typeMap[mangledIdentifier] = type.rawType
//  }
//
//  public mutating func setType(of function: FunctionDeclaration, contractIdentifier: Identifier, callerCapabilities: [CallerCapability], type: Type) {
//    let mangledFunction = function.mangled(enclosingType: contractIdentifier, withCallerCapabilities: callerCapabilities)
//    typeMap[mangledFunction] = type.rawType
//  }

  public enum FunctionCallMatchResult {
    case success(FunctionInformation)
    case failure(candidates: [FunctionInformation])
  }

  public func matchFunctionCall(_ functionCall: FunctionCall, enclosingType: RawTypeIdentifier, callerCapabilities: [CallerCapability]) -> FunctionCallMatchResult {
    var candidates = [FunctionInformation]()

    for candidate in types[enclosingType]!.functions[functionCall.identifier.name]! {
      let argumentTypes = functionCall.arguments.map { type(of: $0, enclosingType: enclosingType) }

      guard candidate.parameterTypes ==  argumentTypes,
        areCallerCapabilitiesCompatible(source: callerCapabilities, target: candidate.callerCapabilities) else {
          candidates.append(candidate)
          continue
      }

      return .success(candidate)
    }

    return .failure(candidates: candidates)
  }

  func areCallerCapabilitiesCompatible(source: [CallerCapability], target: [CallerCapability]) -> Bool {
    for callCallerCapability in source {
      if !target.contains(where: { return callCallerCapability.isSubcapability(callerCapability: $0) }) {
        return false
      }
    }
    return true
  }

  public func matchEventCall(_ functionCall: FunctionCall, enclosingType: RawTypeIdentifier) -> PropertyInformation? {
    let property = types[enclosingType]?.properties[functionCall.identifier.name]
    guard property?.rawType.isEventType ?? false else { return nil }
    return property
//
//    return properties(declaredIn: contractIdentifier).filter({ $0.type.isEventType }).first { event in
//    }
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
//
//struct PropertyType {
//  private var storage = [String: Type]()
//
//  func type(of property: String) -> Type? {
//    return storage[property]
//  }
//
//  mutating func setType(_ type: Type, of property: String) {
//    storage[property] = type
//  }
//}


public struct TypeInformation {
  public enum Kind {
    case `struct`
    case contract
  }

  var kind: Kind
  var properties = [String: PropertyInformation]()
  var functions = [String: [FunctionInformation]]()

  init(kind: Kind) {
    self.kind = kind
  }
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
