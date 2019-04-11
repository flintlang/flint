//
//  Environment.swift
//  AST
//
//  Created by Franklin Schrans on 12/26/17.
//
import Source
import Lexer

/// Information about the source program.
public class Environment {
  /// Information about each type (contracts, structs and traits) which the program define, such as its properties and
  /// functions.
  var types: [RawTypeIdentifier: TypeInformation] = [:]

  /// A list of the names of the contracts which have been declared in the program.
  var declaredContracts: [Identifier] = []

  /// A list of the names of the structs which have been declared in the program.
  var declaredStructs: [Identifier] = []

  /// A list of the names of the enums which have been declared in the program.
  var declaredEnums: [Identifier] = []

  // A list of the names of the traits which have been declared in the program.
  var declaredTraits: [Identifier] = []

  // Call graph - using normalised names
  public var callGraph = [String: [(String, FunctionDeclaration)]]()

  /// The name of the stdlib struct which contains all global functions.
  public static let globalFunctionStructName = "Flint$Global"

  public init() {}

  // MARK: - Property
  public func property(_ identifier: String, _ enclosingType: RawTypeIdentifier) -> PropertyInformation? {
    return types[enclosingType]?.properties[identifier]
  }

  /// The source location of a property declaration.
  public func propertyDeclarationSourceLocation(_ identifier: String,
                                                enclosingType: RawTypeIdentifier) -> SourceLocation? {
    return property(identifier, enclosingType)!.sourceLocation
  }

  /// The names of the properties declared in a type.
  public func properties(in enclosingType: RawTypeIdentifier) -> [String] {
    return types[enclosingType]!.orderedProperties
  }

  /// The list of property declarations in a type.
  public func propertyDeclarations(in enclosingType: RawTypeIdentifier) -> [Property] {
    return types[enclosingType]?.properties.values.map { $0.property } ?? []
  }

  // MARK: - Accessors of type properties

  /// The list of conforming functions in a type.
  public func conformingFunctions(in enclosingType: RawTypeIdentifier) -> [FunctionInformation] {
    return types[enclosingType]!.conformingFunctions
  }

  /// The list of initializers in a type.
  public func initializers(in enclosingType: RawTypeIdentifier) -> [SpecialInformation] {
    return types[enclosingType]!.allInitialisers
  }

  /// The list of fallbacks in a type.
  public func fallbacks(in enclosingType: RawTypeIdentifier) -> [SpecialInformation] {
    return types[enclosingType]!.fallbacks
  }

  /// The list of events in a type.
  public func events(in enclosingType: RawTypeIdentifier) -> [EventInformation] {
    return types[enclosingType]!.allEvents.flatMap({ $1 })
  }

  /// The list of properties declared in a type which can be used as caller protections.
  func declaredCallerProtections(enclosingType: RawTypeIdentifier) -> [String] {
    let properties: [String] = types[enclosingType]!.properties.compactMap { key, value in
      switch value.rawType {
      case .basicType(.address): return key
      case .fixedSizeArrayType(.basicType(.address), _): return key
      case .arrayType(.basicType(.address)): return key
      case .dictionaryType(_, .basicType(.address)): return key
      default: return nil
      }
    }
    let functions: [String] = types[enclosingType]!.functions.compactMap { name, functions in
      for function in functions {
        if function.resultType == .basicType(.address), function.parameterTypes == [] {
          return name
        }
        if function.resultType == .basicType(.bool), function.parameterTypes == [.basicType(.address)] {
          return name
        }
      }
      return nil
    }
    return properties + functions
  }

  public func getStateValue(_ state: Identifier, in contract: RawTypeIdentifier) -> Expression {
    let enumName = ContractDeclaration.contractEnumPrefix + contract
    return types[enumName]!.properties[state.name]!.property.value!
  }

  /// The public initializer for the given contract. A contract should have at most one public initializer.
  public func publicInitializer(forContract contract: RawTypeIdentifier) -> SpecialDeclaration? {
    return types[contract]?.publicInitializer
  }

  /// The public fallback for the given contract. A contract should have at most one public fallback.
  public func publicFallback(forContract contract: RawTypeIdentifier) -> SpecialDeclaration? {
    return types[contract]?.publicFallback
  }

  // MARK: - Compatibility
  func areArgumentsCompatible(source: EventInformation,
                              target: [FunctionArgument],
                              enclosingType: String,
                              scopeContext: ScopeContext) -> Bool {
    let declaredParameters = source.declaration.variableDeclarations
    let declarationTypes = source.eventTypes

    guard target.count <= source.parameterIdentifiers.count &&
          target.count >= source.requiredParameterIdentifiers.count else {
      return false
    }

    return checkParameterCompatibility(of: target,
                                       against: declaredParameters,
                                       withTypes: declarationTypes,
                                       enclosingType: enclosingType,
                                       scopeContext: scopeContext)
  }

  // Attempts to replace Self in rawTypeList with the given enclosingType
  func replaceSelf(in rawTypeList: [RawType], enclosingType: RawTypeIdentifier) -> [RawType] {
    return rawTypeList.map { $0.replacingSelf(with: enclosingType) }
  }

  /// Whether two function arguments are compatible.
  ///
  /// # What is compatibility?
  /// Compatibility means that `source` and `target` are equal following a replacement
  /// of all ocurrences of `Self` in `source`.
  ///
  /// - Parameters:
  ///   - source: arguments of the function that the user is trying to use.
  ///   - target: arguments of the function available in this scope.
  ///   - enclosingType: Type identifier of type containing *source* function.
  /// - Returns: Boolean indicating whether function arguments are compatible.
  func areFunctionArgumentsCompatible(source: [RawType],
                                      target: [RawType],
                                      enclosingType: RawTypeIdentifier) -> Bool {
    // If source contains an argument of self type then attempt to replace with enclosing type
    let sourceSelf = replaceSelf(in: source, enclosingType: enclosingType)
    return sourceSelf == target
  }

  /// Function that checks whether the arguments of a function call are compatible
  /// (i.e. the call could be successfully made) with a function declaration.
  /// - Parameters:
  ///   - source: function information of the function that the user is trying to call.
  ///   - target: function call that the user is trying to make.
  /// - Returns: Boolean indicating whether function call arguments are compatible.
  func areFunctionCallArgumentsCompatible(source: FunctionInformation,
                                          target: FunctionCall,
                                          enclosingType: RawTypeIdentifier,
                                          scopeContext: ScopeContext) -> Bool {
    // If source contains an argument of self type then attempt to replace with enclosing type
    let declarationTypesNoSelf = replaceSelf(in: source.parameterTypes, enclosingType: enclosingType)
    let declaredParameters = source.declaration.signature.parameters.map({ $0.asVariableDeclaration })

    guard target.arguments.count <= source.parameterIdentifiers.count &&
          target.arguments.count >= source.requiredParameterIdentifiers.count else {
      return false
    }

    return checkParameterCompatibility(of: target.arguments,
                                       against: declaredParameters,
                                       withTypes: declarationTypesNoSelf,
                                       enclosingType: enclosingType,
                                       scopeContext: scopeContext)
  }

  func checkParameterCompatibility(of callArguments: [FunctionArgument],
                                   against declaredParameters: [VariableDeclaration],
                                   withTypes declarationTypes: [RawType],
                                   enclosingType: RawTypeIdentifier,
                                   scopeContext: ScopeContext) -> Bool {
    var declaredIndex = 0
    var callArgumentIndex = 0

    // Check required parameters first
    while declaredIndex < declaredParameters.count && declaredParameters[declaredIndex].assignedExpression == nil {
      // Check identifiers
      if callArguments[callArgumentIndex].identifier != nil {
        if callArguments[callArgumentIndex].identifier!.name != declaredParameters[declaredIndex].identifier.name {
          return false
        }
      }

      // Check types
      if declarationTypes[declaredIndex] != type(of: callArguments[callArgumentIndex].expression,
                                                 enclosingType: enclosingType,
                                                 scopeContext: scopeContext).replacingSelf(with: enclosingType) {
        // Wrong type
        return false
      }

      declaredIndex += 1
      callArgumentIndex += 1
    }

    // Check default parameters
    while declaredIndex < declaredParameters.count && callArgumentIndex < callArguments.count {
      guard let argumentIdentifier = callArguments[callArgumentIndex].identifier else {
        if declarationTypes[declaredIndex] != type(of: callArguments[callArgumentIndex].expression,
                                                   enclosingType: enclosingType,
                                                   scopeContext: scopeContext).replacingSelf(with: enclosingType) {
          return false
        }

        declaredIndex += 1
        callArgumentIndex += 1
        continue
      }

      while declaredIndex < declaredParameters.count &&
          argumentIdentifier.name != declaredParameters[declaredIndex].identifier.name {
        declaredIndex += 1
      }

      if declaredIndex == declaredParameters.count {
        // Identifier was not found
        return false
      }

      if declarationTypes[declaredIndex] != type(of: callArguments[callArgumentIndex].expression,
                                                 enclosingType: enclosingType,
                                                 scopeContext: scopeContext).replacingSelf(with: enclosingType) {
        // Wrong type
        return false
      }

      declaredIndex += 1
      callArgumentIndex += 1
    }

    if callArgumentIndex < callArguments.count {
      // Not all arguments were matches
      return false
    }

    return true
  }

  /// Whether two function signatures are compatible.
  ///
  /// # What is compatibility?
  /// Compatibility means that `source` and `target` are equal following a replacement
  /// of all ocurrences of `Self` in `source`.
  ///
  /// - Parameters:
  ///   - source: signature declaration of the function that the user is trying to use.
  ///   - target: signature declaration of the function available in this scope.
  ///   - enclosingType: Type identifier of type containing *source* function.
  /// - Returns: Boolean indicating whether two function signatures are compatible.
  func areFunctionSignaturesCompatible(source: FunctionSignatureDeclaration,
                                       target: FunctionSignatureDeclaration,
                                       enclosingType: RawTypeIdentifier) -> Bool {
    // Lifted directly from FunctionSignatureDeclaration.
    return source.identifier.name == target.identifier.name &&
      source.modifiers.map({ $0.kind }) == target.modifiers.map({ $0.kind }) &&
      source.attributes.map({ $0.kind }) == target.attributes.map({ $0.kind }) &&
      source.resultType?.rawType == target.resultType?.rawType &&
      source.parameters.identifierNames == target.parameters.identifierNames &&
      areFunctionArgumentsCompatible(source: source.parameters.rawTypes,
                                     target: target.parameters.rawTypes,
                                     enclosingType: enclosingType) &&
      source.parameters.map({ $0.isInout }) == target.parameters.map({ $0.isInout })
  }

  /// Whether two caller protection groups are compatible, i.e. whether a function with caller protection `source` is
  /// able to call a function which require caller protections `target`.
  func areCallerProtectionsCompatible(source: [CallerProtection], target: [CallerProtection]) -> Bool {
    guard !target.isEmpty else { return true }
    for callCallerProtection in source {
      if !target.contains(where: { return callCallerProtection.isSubProtection(of: $0) }) {
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

// MARK: Environment - Checks -

  /// The prefix for Flint runtime functions.
  public static var runtimeFunctionPrefix = "flint$"

  /// Whether the given function call is a runtime function.
  public static func isRuntimeFunctionCall(_ functionCall: FunctionCall) -> Bool {
    return functionCall.identifier.name.starts(with: runtimeFunctionPrefix)
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

  /// Whether a trait has been declared in the program.
  public func isTraitDeclared(_ type: RawTypeIdentifier) -> Bool {
    return declaredTraits.contains { $0.name == type }
  }

  /// Whether a type has been declared in the program.
  public func isTypeDeclared(_ type: RawTypeIdentifier) -> Bool {
    return types[type] != nil
  }

  // Whether a contract is stateful.
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
  public func selfReferentialProperty(in type: RawTypeIdentifier,
                                      enclosingType: RawTypeIdentifier) -> PropertyInformation? {
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

  /// Whether property is declared as a constant.
  public func isPropertyConstant(_ identifier: String, enclosingType: RawTypeIdentifier) -> Bool {
    return property(identifier, enclosingType)!.isConstant
  }

  // Whether a property is assigned a default value
  public func isPropertyAssignedDefaultValue(_ identifier: String, enclosingType: RawTypeIdentifier) -> Bool {
    return property(identifier, enclosingType)!.isAssignedDefaultValue
  }

  // Whether an identifier is redeclared
  private func isRedeclaration(_ identifier1: Identifier, _ identifier2: Identifier) -> Bool {
    return identifier1 != identifier2 &&
      identifier1.name == identifier2.name &&
      identifier1.sourceLocation.line < identifier2.sourceLocation.line
  }

  // Whether declarations conflict
  private func conflictingDeclaration(of identifier: Identifier, in identifiers: [Identifier]) -> Identifier? {
    return identifiers
      .filter({ isRedeclaration($0, identifier) })
      .lazy.sorted(by: { $0.sourceLocation.line < $1.sourceLocation.line }).first
  }

  /// Attempts to find a conflicting declaration of the given type.
  public func conflictingTypeDeclaration(for type: Identifier) -> Identifier? {
    return conflictingDeclaration(of: type, in: declaredStructs + declaredContracts + declaredEnums + declaredTraits)
  }

  /// Attempts to find a conflicting event declaration in given contract.
  public func conflictingEventDeclaration(for event: Identifier, in type: RawTypeIdentifier) -> Identifier? {
    let declaredEvents = types[type]!.allEvents[event.name]?.map { $0.declaration.identifier } ?? []
    return conflictingDeclaration(of: event, in: declaredEvents + declaredStructs + declaredContracts + declaredEnums)
  }

  /// Attempts to find a conflicting declaration of the given function declaration
  public func conflictingFunctionDeclaration(for function: FunctionDeclaration,
                                             in type: RawTypeIdentifier) -> Identifier? {
    var contractFunctions = [Identifier]()

    if isContractDeclared(type) {
      // Contract functions do not support overloading.
      contractFunctions = types[type]!.allFunctions[function.name]?
        .filter({ !$0.isSignature })
        .map { $0.declaration.identifier } ?? []
    }

    if let conflict = conflictingDeclaration(of: function.identifier,
                                             in: contractFunctions + declaredStructs + declaredContracts) {
      return conflict
    }

    let functions = types[type]!.allFunctions[function.name]?.filter { functionInformation in
      let identifier1 = function.identifier
      let identifier2 = functionInformation.declaration.identifier
      let parameterList1 = function.signature.parameters.map { $0.type.rawType.name }
      let parameterList2 = functionInformation.declaration.signature.parameters.map { $0.type.rawType.name }

      return !functionInformation.isSignature &&
        identifier1.name == identifier2.name &&
        parameterList1 == parameterList2 &&
        identifier1.sourceLocation < identifier2.sourceLocation
    }

    return functions?.first?.declaration.identifier
  }

  /// Attempts to find a conflicting declaration of the given property declaration.
  public func conflictingPropertyDeclaration(for identifier: Identifier, in type: RawTypeIdentifier) -> Identifier? {
    return conflictingDeclaration(of: identifier, in: propertyDeclarations(in: type).map { $0.identifier })
  }

  // Two signatures conflict if trait functions with the same name have equal parameters
  // but different modifiers, label names, etc
  public func conflictingTraitSignatures(for type: RawTypeIdentifier) -> [String: [FunctionInformation]] {
    guard let typeInfo = types[type] else {
      return [:]
    }
    return typeInfo.traitFunctions.filter { (_, functions) in
      functions.count > 1 && functions.contains(where: {
        let compare = $0.declaration.signature
        let against = functions.first!.declaration.signature

        return compare.parameters.rawTypes == against.parameters.rawTypes && compare != against
      })
    }
  }

  /// Whether the given caller protection is declared in the given type.
  public func containsCallerProtection(_ callerProtection: CallerProtection, enclosingType: RawTypeIdentifier) -> Bool {
    return declaredCallerProtections(enclosingType: enclosingType).contains(callerProtection.name)
  }

  public func undefinedFunctions(in enclosingType: Identifier) -> [FunctionInformation] {
    let typeInfo = types[enclosingType.name]!
    var notImplemented = [FunctionInformation]()
    for name in typeInfo.allFunctions.keys {
      if let signature = typeInfo.allFunctions[name]?.filter({ $0.isSignature }).first {
        let conforming = typeInfo.functions[name]?.filter({ !$0.isSignature }) ?? []
        if conforming.isEmpty {
          notImplemented.append(contentsOf: typeInfo.allFunctions[name]!)
        }
        for conform in conforming where !areFunctionSignaturesCompatible(source: signature.declaration.signature,
                                                                         target: conform.declaration.signature,
                                                                         enclosingType: enclosingType.name) {
                                                                          notImplemented.append(conform)
        }
      }
    }
    return notImplemented
  }

  public func undefinedInitialisers(in enclosingType: Identifier) -> [SpecialInformation] {
    let typeInfo = types[enclosingType.name]!
    if let conforming = typeInfo.initializers.filter({ !$0.isSignature }).first { // Compatibility check
      if let signature = typeInfo.allInitialisers.filter({ $0.isSignature }).first,
        !areFunctionSignaturesCompatible(source: signature.declaration.signature.asFunctionSignatureDeclaration,
                                         target: conforming.declaration.signature.asFunctionSignatureDeclaration,
                                         enclosingType: enclosingType.name) {
        return [signature]
      }
      return []
    }
    return typeInfo.allInitialisers
  }

  public func isConforming(_ function: FunctionDeclaration, in enclosingType: RawTypeIdentifier) -> Bool {
    let signature = types[enclosingType]?.allFunctions[function.identifier.name]?.filter({ $0.isSignature }).first
    return function.signature == signature?.declaration.signature
  }
}
