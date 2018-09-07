//
//  Environment+Additions.swift
//  AST
//
//  Created by Hails, Daniel J R on 22/08/2018.
//
import Source

extension Environment {
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
      addFunction(functionDeclaration, enclosingType: structDeclaration.identifier.name, states: [], callerCapabilities: [])
    }
    for specialDeclaration in structDeclaration.specialDeclarations {
      if specialDeclaration.isInit {
        addInitializer(specialDeclaration, enclosingType: structDeclaration.identifier.name)
      }
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

  /// Add an event declaration to the environment.
  public mutating func addEvent(_ eventDeclaration: EventDeclaration, enclosingType: RawTypeIdentifier) {
    let eventName = eventDeclaration.identifier.name

    types[enclosingType, default: TypeInformation()]
      .events[eventName, default: [EventInformation]()]
      .append(EventInformation(declaration: eventDeclaration))
  }

  /// Add a function declaration to a type (contract or struct). In the case of a contract, a list of caller
  /// capabilities is expected.
  public mutating func addFunction(_ functionDeclaration: FunctionDeclaration, enclosingType: RawTypeIdentifier, states: [TypeState], callerCapabilities: [CallerCapability]) {
    let functionName = functionDeclaration.identifier.name

    types[enclosingType, default: TypeInformation()]
      .functions[functionName, default: [FunctionInformation]()]
      .append(FunctionInformation(declaration: functionDeclaration, typeStates: states, callerCapabilities: callerCapabilities, isMutating: functionDeclaration.isMutating))
  }

  /// Add an initializer declaration to a type (contract or struct). In the case of a contract, a list of caller
  /// capabilities is expected.
  public mutating func addInitializer(_ initializerDeclaration: SpecialDeclaration, enclosingType: RawTypeIdentifier, callerCapabilities: [CallerCapability] = []) {
    types[enclosingType, default: TypeInformation()]
      .initializers
      .append(SpecialInformation(declaration: initializerDeclaration, callerCapabilities: callerCapabilities))
  }

  /// Add an initializer declaration to a type (contract or struct). In the case of a contract, a list of caller
  /// capabilities is expected.
  public mutating func addFallback(_ fallbackDeclaration: SpecialDeclaration, enclosingType: RawTypeIdentifier, callerCapabilities: [CallerCapability] = []) {
    types[enclosingType, default: TypeInformation()].fallbacks.append(SpecialInformation(declaration: fallbackDeclaration, callerCapabilities: callerCapabilities))
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

  /// Add a conformance to a type.
  public mutating func addConformance(_ type: RawTypeIdentifier, conformsTo trait: RawTypeIdentifier) {
    types[type]!.conformances.append(types[trait]!)
  }

  /// Add a trait to the environment.
  public mutating func addTrait(_ traitDeclaration: TraitDeclaration) {
    types[traitDeclaration.identifier.name] = TypeInformation()
  }

  /// Add a use of an undefined variable.
  public mutating func addUsedUndefinedVariable(_ variable: Identifier, enclosingType: RawTypeIdentifier) {
    let declaration = VariableDeclaration(modifiers: [], declarationToken: nil, identifier: variable, type: Type(inferredType: .errorType, identifier: variable))
    addProperty(.variableDeclaration(declaration), enclosingType: enclosingType)
  }

  /// Set the public initializer for the given contract. A contract should have at most one public initializer.
  public mutating func setPublicInitializer(_ publicInitializer: SpecialDeclaration, forContract contract: RawTypeIdentifier) {
    types[contract]!.publicInitializer = publicInitializer
  }

  /// Set the public fallback for the given contract. A contract should have at most one public fallback.
  public mutating func setPublicFallback(_ publicFallback: SpecialDeclaration, forContract contract: RawTypeIdentifier) {
    types[contract]!.publicFallback = publicFallback
  }
}
