//
//  Environment.swift
//  AST
//
//  Created by Franklin Schrans on 12/26/17.
//
import Source
import Lexer

/// Information about the source program.
public struct Environment {
  /// Information about each type (contracts, structs and traits) which the program define, such as its properties and
  /// functions.
  var types = [RawTypeIdentifier: TypeInformation]()

  /// A list of the names of the contracts which have been declared in the program.
  var declaredContracts = [Identifier]()

  /// A list of the names of the structs which have been declared in the program.
  var declaredStructs = [Identifier]()

  /// A list of the names of the enums which have been declared in the program.
  var declaredEnums = [Identifier]()

  // A list of the names of the traits which have been declared in the program.
  var declaredTraits = [Identifier]()

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
  func areArgumentsCompatible(source: [FunctionArgument],
                              target: EventInformation,
                              enclosingType: String,
                              scopeContext: ScopeContext) -> Bool {
    let targetVariables = target.declaration.variableDeclarations
    let targetTypes = target.eventTypes

    guard source.count <= target.parameterIdentifiers.count else {
      return false
    }
    guard source.count >= target.requiredParameterIdentifiers.count else {
      return false
    }

    var sourceIndex = 0
    var targetIndex = 0
    while sourceIndex < source.count && targetIndex < targetVariables.count {
      if let identifier = source[sourceIndex].identifier,
        identifier.name != targetVariables[targetIndex].identifier.name {
        if targetVariables[targetIndex].assignedExpression == nil {
          return false
        } else {
          targetIndex+=1
          continue
        }
      }
      if targetTypes[targetIndex] == type(of: source[sourceIndex].expression,
                                          enclosingType: enclosingType,
                                          scopeContext: scopeContext) {
        sourceIndex+=1
        targetIndex+=1
      } else {
        return false
      }
    }
    return true
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
  func areFunctionArgumentsCompatible(source: [RawType], target: [RawType], enclosingType: RawTypeIdentifier) -> Bool {
    // If source contains an argument of self type then attempt to replace with enclosing type
    let sourceSelf = source.map { type -> RawType in
      if type.isSelfType {
        if type.isInout {
          return .inoutType(.userDefinedType(enclosingType))
        }

        return .userDefinedType(enclosingType)
      }

      return type
    }

    return sourceSelf == target
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
}
