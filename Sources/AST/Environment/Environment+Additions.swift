//
//  Environment+Additions.swift
//  AST
//
//  Created by Hails, Daniel J R on 22/08/2018.
//
import Source

extension Environment {
  /// Add a contract declaration to the environment.
  public mutating func addContract(_ contract: ContractDeclaration) {
    declaredContracts.append(contract.identifier)
    types[contract.identifier.name] = TypeInformation()
    setProperties(contract.variableDeclarations.map{ .variableDeclaration($0) }, enclosingType: contract.identifier.name)

    for conformance in contract.conformances {
      addConformance(contract.identifier.name, conformsTo: conformance.name)
    }
    if contract.isStateful {
      addEnum(contract.stateEnum)
    }
    for member in contract.members {
      if case .eventDeclaration(let eventDeclaration) = member {
        addEvent(eventDeclaration, enclosingType: contract.identifier.name)
      }
    }
  }

  /// Add a contract behaviour declaration to the environment.
  public mutating func addContractBehaviour(_ behaviour: ContractBehaviorDeclaration) {
    let contractIdentifier = behaviour.contractIdentifier
    for member in behaviour.members {
      switch member {
      case .functionDeclaration(let functionDeclaration):
        // Record all the function declarations.
        addFunction(functionDeclaration, enclosingType: contractIdentifier.name, states: behaviour.states, callerCapabilities: behaviour.callerCapabilities)
      case .specialDeclaration(let specialDeclaration):
        addSpecial(specialDeclaration, enclosingType: behaviour.contractIdentifier, callerCapabilities: behaviour.callerCapabilities)
      }
    }
  }

  /// Add a struct declaration to the environment.
  public mutating func addStruct(_ structDeclaration: StructDeclaration) {
    declaredStructs.append(structDeclaration.identifier)
    if types[structDeclaration.identifier.name] == nil {
      types[structDeclaration.identifier.name] = TypeInformation()
    }
    setProperties(structDeclaration.variableDeclarations.map{ .variableDeclaration($0) }, enclosingType: structDeclaration.identifier.name)

    for conformance in structDeclaration.conformances {
      addConformance(structDeclaration.identifier.name, conformsTo: conformance.name)
    }

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

  public mutating func addSpecial(_ special: SpecialDeclaration, enclosingType: Identifier, callerCapabilities: [CallerCapability]) {
    if special.isInit {
      addInitializer(special, enclosingType: enclosingType.name)
      if special.isPublic, publicInitializer(forContract: enclosingType.name) == nil {
        // Record the public initializer, we will need to know if one of was declared during semantic analysis of the
        // contract's state properties.
        setPublicInitializer(special, for: enclosingType.name)
      }
    } else if special.isFallback {
      addFallback(special, enclosingType: enclosingType.name)
    }
  }

  /// Add a function declaration to a type (contract or struct). In the case of a contract, a list of caller
  /// capabilities is expected.
  public mutating func addFunction(_ functionDeclaration: FunctionDeclaration, enclosingType: RawTypeIdentifier, states: [TypeState], callerCapabilities: [CallerCapability]) {
    let functionName = functionDeclaration.name

    types[enclosingType, default: TypeInformation()]
      .functions[functionName, default: [FunctionInformation]()]
      .append(FunctionInformation(declaration: functionDeclaration, typeStates: states, callerCapabilities: callerCapabilities, isMutating: functionDeclaration.isMutating, isSignature: false))
  }

  /// Add an initializer declaration to a type (contract or struct). In the case of a contract, a list of caller
  /// capabilities is expected.
  public mutating func addInitializer(_ initializerDeclaration: SpecialDeclaration, enclosingType: RawTypeIdentifier, callerCapabilities: [CallerCapability] = []) {
    types[enclosingType, default: TypeInformation()]
      .initializers
      .append(SpecialInformation(declaration: initializerDeclaration, callerCapabilities: callerCapabilities, isSignature: false))
  }

  /// Add a function declaration to a type (contract or struct). In the case of a contract, a list of caller
  /// capabilities is expected.
  public mutating func addFunctionSignature(_ signature: FunctionSignatureDeclaration, enclosingType: RawTypeIdentifier, states: [TypeState], callerCapabilities: [CallerCapability]) {
    let functionName = signature.identifier.name

    let functionDeclaration = FunctionDeclaration(signature: signature, body: [], closeBraceToken: .init(kind: .punctuation(.closeBrace), sourceLocation: .DUMMY))

    types[enclosingType, default: TypeInformation()]
      .functions[functionName, default: [FunctionInformation]()]
      .append(FunctionInformation(declaration: functionDeclaration, typeStates: states, callerCapabilities: callerCapabilities, isMutating: functionDeclaration.isMutating, isSignature: true))
  }

  /// Add an initializer declaration to a type (contract or struct). In the case of a contract, a list of caller
  /// capabilities is expected.
  public mutating func addInitializerSignature(_ initalizerSignature: SpecialSignatureDeclaration, enclosingType: RawTypeIdentifier, callerCapabilities: [CallerCapability] = []) {

    let specialDeclaration = SpecialDeclaration(signature: initalizerSignature, body: [], closeBraceToken: .init(kind: .punctuation(.closeBrace), sourceLocation: .DUMMY))

    types[enclosingType, default: TypeInformation()]
      .initializers
      .append(SpecialInformation(declaration: specialDeclaration, callerCapabilities: callerCapabilities, isSignature: true))
  }


  /// Add an initializer declaration to a type (contract or struct). In the case of a contract, a list of caller
  /// capabilities is expected.
  public mutating func addFallback(_ fallbackDeclaration: SpecialDeclaration, enclosingType: RawTypeIdentifier, callerCapabilities: [CallerCapability] = []) {
    types[enclosingType, default: TypeInformation()].fallbacks.append(SpecialInformation(declaration: fallbackDeclaration, callerCapabilities: callerCapabilities, isSignature: false))
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
    if types[trait] != nil {
      types[type]!.conformances.append(types[trait]!)
    }
  }

  /// Add a trait to the environment.
  public mutating func addTrait(_ trait: TraitDeclaration) {
    declaredTraits.append(trait.identifier)
    types[trait.identifier.name] = TypeInformation()
    for member in trait.members {
      if case .eventDeclaration(let eventDeclaration) = member {
        addEvent(eventDeclaration, enclosingType: trait.identifier.name)
      } else if case .functionDeclaration(let functionDeclaration) = member {
        addFunction(functionDeclaration, enclosingType: trait.identifier.name, states: [], callerCapabilities: [])
      } else if case .specialDeclaration(let specialDeclaration) = member {
        addSpecial(specialDeclaration, enclosingType: trait.identifier, callerCapabilities: [])
      } else if case .functionSignatureDeclaration(let signature) = member {
        addFunctionSignature(signature, enclosingType: trait.identifier.name, states: [], callerCapabilities: [])
      } else if case .specialSignatureDeclaration(let signature) = member {
        addInitializerSignature(signature, enclosingType: trait.identifier.name, callerCapabilities: [])
      }
    }
  }

  /// Add a use of an undefined variable.
  public mutating func addUsedUndefinedVariable(_ variable: Identifier, enclosingType: RawTypeIdentifier) {
    let declaration = VariableDeclaration(modifiers: [], declarationToken: nil, identifier: variable, type: Type(inferredType: .errorType, identifier: variable))
    addProperty(.variableDeclaration(declaration), enclosingType: enclosingType)
  }

  /// Set the public initializer for the given contract. A contract should have at most one public initializer.
  public mutating func setPublicInitializer(_ publicInitializer: SpecialDeclaration, for type: RawTypeIdentifier) {
    types[type]!.publicInitializer = publicInitializer
  }

  /// Set the public fallback for the given contract. A contract should have at most one public fallback.
  public mutating func setPublicFallback(_ publicFallback: SpecialDeclaration, for type: RawTypeIdentifier) {
    types[type]!.publicFallback = publicFallback
  }
}
