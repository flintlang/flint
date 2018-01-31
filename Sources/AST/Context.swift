//
//  Context.swift
//  AST
//
//  Created by Franklin Schrans on 12/26/17.
//

public struct Environment {
  var contractDeclarations = [ContractDeclaration]()
  var structDeclarations = [StructDeclaration]()
  var functions = [MangledFunction]()

  var propertyMap = [Identifier: [VariableDeclaration]]()
  var typeMap = [AnyHashable: Type.RawType]()
  var typeUndefinedVariables = [Identifier: [Identifier]]()

  public var declaredContractsIdentifiers: [Identifier] {
    return contractDeclarations.map { $0.identifier }
  }

  var typeLayoutMap = [Identifier: TypeLayout]()

  public init() {}

  public mutating func addFunction(_ functionDeclaration: FunctionDeclaration, typeIdentifier: Identifier, callerCapabilities: [CallerCapability] = []) {
    let mangledFunction = functionDeclaration.mangled(enclosingType: typeIdentifier, withCallerCapabilities: callerCapabilities)
    functions.append(mangledFunction)
    typeMap[mangledFunction] = mangledFunction.resultType?.rawType ?? .builtInType(.void)
  }

  public mutating func addVariableDeclarations(_ variableDeclarations: [VariableDeclaration], for contractIdentifier: Identifier) {
    propertyMap[contractIdentifier, default: []].append(contentsOf: variableDeclarations)

    for variableDeclaration in variableDeclarations {
      typeMap[variableDeclaration.identifier.mangled(in: contractIdentifier)] = variableDeclaration.type.rawType
    }
  }

  public mutating func addUsedUndefinedVariable(_ variable: Identifier, contractIdentifier: Identifier) {
    typeUndefinedVariables[contractIdentifier, default: []].append(variable)
  }

  public mutating func addContract(_ contractDeclaration: ContractDeclaration) {
    contractDeclarations.append(contractDeclaration)
    addVariableDeclarations(contractDeclaration.variableDeclarations, enclosingType: contractDeclaration.identifier)
  }

  public mutating func addStruct(_ structDeclaration: StructDeclaration) {
    structDeclarations.append(structDeclaration)
    addVariableDeclarations(structDeclaration.variableDeclarations, enclosingType: structDeclaration.identifier)
  }

  mutating func addVariableDeclarations(_ variableDeclarations: [VariableDeclaration], enclosingType: Identifier) {
    var offsetMap = [String: Int]()
    var offset = 0

    for variableDeclaration in variableDeclarations {
      let propertyIdentifier = variableDeclaration.identifier
      offsetMap[propertyIdentifier.name] = offset

      let propertyType = variableDeclaration.type.rawType
      let propertySize = size(of: propertyType)

      offset += propertySize
    }

    typeLayoutMap[enclosingType] = TypeLayout(offsetMap: offsetMap)
  }

  public func size(of type: Type.RawType) -> Int {
    switch type {
    case .builtInType(_): return 1
    case .fixedSizeArrayType(let rawType, let elementCount): return size(of: rawType) * elementCount
    case .arrayType(_): return 1
    case .dictionaryType(_, _): return 1
    case .errorType: return 0

    case .userDefinedType(let identifier):
      let propertyDeclarations = properties(declaredIn: identifier)
      return propertyDeclarations.reduce(0, { acc, element in
        return acc + size(of: element.type.rawType)
      })
    }
  }

  func matchStruct(identifier: Identifier) -> StructDeclaration? {
    return structDeclarations.first(where: { $0.identifier == identifier })
  }

  public func properties(declaredIn type: Identifier) -> [VariableDeclaration] {
    if let contractDeclaration = contractDeclarations.first(where: { $0.identifier == type }) {
      return contractDeclaration.variableDeclarations
    }

    if let structDeclaration = matchStruct(identifier: type) {
      return structDeclaration.variableDeclarations
    }
    return []
  }

  public func propertyOffset(for property: Identifier, in type: Identifier) -> Int? {
    return typeLayoutMap[type]?.offset(for: property.name)
  }

  func declaredCallerCapabilities(contractIdentifier: Identifier) -> [VariableDeclaration] {
    let contractDefinitionIdentifier = declaredContractsIdentifiers.first { $0.name == contractIdentifier.name }!
      guard let variables = propertyMap[contractDefinitionIdentifier] else { return [] }
    return variables.filter { variable in
      switch variable.type.rawType {
      case .builtInType(.address): return true
      case .fixedSizeArrayType(.builtInType(.address), _): return true
      case .arrayType(let rawType): return rawType == .builtInType(.address)
      default: return false
      }
    }
  }

  public func containsCallerCapability(_ callerCapability: CallerCapability, in contractIdentifier: Identifier) -> Bool {
    return declaredCallerCapabilities(contractIdentifier: contractIdentifier).contains(where: { $0.identifier.name == callerCapability.identifier.name })
  }

  public func type(of identifier: Identifier, typeIdentifier: Identifier) -> Type.RawType? {
    if typeUndefinedVariables[typeIdentifier, default: []].contains(identifier) {
      return .errorType
    }
    let mangledIdentifier = identifier.mangled(in: typeIdentifier)
    return typeMap[mangledIdentifier]
  }

  public func type(of functionCall: FunctionCall, contractIdentifier: Identifier, callerCapabilities: [CallerCapability]) -> Type.RawType? {
    guard case .success(let matchingFunction) = matchFunctionCall(functionCall, contractIdentifier: contractIdentifier, callerCapabilities: callerCapabilities) else { return .errorType }
    return typeMap[matchingFunction]
  }

  public func type(of expression: Expression, functionDeclarationContext: FunctionDeclarationContext? = nil, typeIdentifier: Identifier, callerCapabilities: [CallerCapability] = []) -> Type.RawType {
    switch expression {
    case .binaryExpression(let binaryExpression):
      return type(of: binaryExpression.rhs, functionDeclarationContext: functionDeclarationContext, typeIdentifier: typeIdentifier, callerCapabilities: callerCapabilities)

    case .bracketedExpression(let expression):
      return type(of: expression, functionDeclarationContext: functionDeclarationContext, typeIdentifier: typeIdentifier, callerCapabilities: callerCapabilities)

    case .functionCall(let functionCall):
      return type(of: functionCall, contractIdentifier: typeIdentifier, callerCapabilities: callerCapabilities) ?? .errorType

    case .identifier(let identifier):
      if identifier.enclosingType == nil,
        let functionDeclarationContext = functionDeclarationContext,
        let localVariable = functionDeclarationContext.declaration.matchingLocalVariable(identifier) {
        return localVariable.type.rawType
      }
      return type(of: identifier, typeIdentifier: typeIdentifier)!

    case .literal(let token):
      guard case .literal(let literal) = token.kind else { fatalError() }
      switch literal {
      case .boolean(_): return .builtInType(.bool)
      case .decimal(.integer(_)): return .builtInType(.int)
      default: fatalError()
      }
    case .self(_): return .userDefinedType(typeIdentifier)
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.type.rawType
    case .subscriptExpression(let subscriptExpression):
      let identifierType = type(of: subscriptExpression.baseIdentifier, typeIdentifier: typeIdentifier)!

      switch identifierType {
      case .arrayType(let elementType): return elementType
      case .fixedSizeArrayType(let elementType, _): return elementType
      case .dictionaryType(_, let valueType): return valueType
      default: fatalError()
      }
    }
  }

  public mutating func setType(of identifier: Identifier, contractIdentifier: Identifier, type: Type) {
    let mangledIdentifier = identifier.mangled(in: contractIdentifier)
    typeMap[mangledIdentifier] = type.rawType
  }

  public mutating func setType(of function: FunctionDeclaration, contractIdentifier: Identifier, callerCapabilities: [CallerCapability], type: Type) {
    let mangledFunction = function.mangled(enclosingType: contractIdentifier, withCallerCapabilities: callerCapabilities)
    typeMap[mangledFunction] = type.rawType
  }

  public enum FunctionCallMatchResult {
    case success(MangledFunction)
    case failure(candidates: [MangledFunction])
  }

  public func matchFunctionCall(_ functionCall: FunctionCall, contractIdentifier: Identifier, callerCapabilities: [CallerCapability]) -> FunctionCallMatchResult {
    var candidates = [MangledFunction]()

    for function in functions {
      if function.canBeCalledBy(functionCall: functionCall, contractIdentifier: contractIdentifier, callerCapabilities: callerCapabilities) {
        return .success(function)
      }

      if function.hasSameSignatureAs(functionCall) {
        candidates.append(function)
      }
    }

    return .failure(candidates: candidates)
  }

  public func matchEventCall(_ functionCall: FunctionCall, contractIdentifier: Identifier) -> VariableDeclaration? {
    return properties(declaredIn: contractIdentifier).filter({ $0.type.isEventType }).first { event in
      return functionCall.identifier == event.identifier && event.type.genericArguments.count == functionCall.arguments.count
    }
  }
}

struct TypeLayout {
  private var storage = [String: Int]()

  func offset(for propertyName: String) -> Int? {
    return storage[propertyName]
  }

  init(offsetMap: [String: Int]) {
    storage = offsetMap
  }
}
