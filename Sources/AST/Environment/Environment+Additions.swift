//
//  Environment+Additions.swift
//  AST
//
//  Created by Hails, Daniel J R on 22/08/2018.
//
import Source
import Lexer

extension Environment {
  /// Add a contract declaration to the environment.
  public func addContract(_ contract: ContractDeclaration) {
    declaredContracts.append(contract.identifier)
    types[contract.identifier.name] = TypeInformation()
    setProperties(contract.variableDeclarations.map { .variableDeclaration($0) },
                  enclosingType: contract.identifier.name)

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
  public func addContractBehaviour(_ behaviour: ContractBehaviorDeclaration) {
    let contractIdentifier = behaviour.contractIdentifier
    for member in behaviour.members {
      switch member {
      case .functionDeclaration(let functionDeclaration):
        // Record all the function declarations.
        addFunction(functionDeclaration, enclosingType: contractIdentifier.name,
                    states: behaviour.states,
                    callerProtections: behaviour.callerProtections)
      case .specialDeclaration(let specialDeclaration):
        addSpecial(specialDeclaration,
                   enclosingType: behaviour.contractIdentifier,
                   callerProtections: behaviour.callerProtections)
      case .functionSignatureDeclaration, .specialSignatureDeclaration:
        break
      }
    }
  }

  /// Add a struct declaration to the environment.
  public func addStruct(_ structDeclaration: StructDeclaration) {
    declaredStructs.append(structDeclaration.identifier)
    if types[structDeclaration.identifier.name] == nil {
      types[structDeclaration.identifier.name] = TypeInformation()
    }
    setProperties(structDeclaration.variableDeclarations.map { .variableDeclaration($0) },
                  enclosingType: structDeclaration.identifier.name)

    for conformance in structDeclaration.conformances {
      addConformance(structDeclaration.identifier.name, conformsTo: conformance.name)
    }

    for functionDeclaration in structDeclaration.functionDeclarations {
      addFunction(functionDeclaration,
                  enclosingType: structDeclaration.identifier.name,
                  states: [],
                  callerProtections: [])
    }

    for specialDeclaration in structDeclaration.specialDeclarations where specialDeclaration.isInit {
      addInitializer(specialDeclaration, enclosingType: structDeclaration.identifier.name)
    }
  }

  /// Add an enum declaration to the environment.
  public func addEnum(_ enumDeclaration: EnumDeclaration) {
    declaredEnums.append(enumDeclaration.identifier)
    if types[enumDeclaration.identifier.name] == nil {
      types[enumDeclaration.identifier.name] = TypeInformation()
    }
    setProperties(enumDeclaration.cases.map { .enumCase($0) }, enclosingType: enumDeclaration.identifier.name)
  }

  /// Add an event declaration to the environment.
  public func addEvent(_ eventDeclaration: EventDeclaration, enclosingType: RawTypeIdentifier) {
    let eventName = eventDeclaration.identifier.name

    types[enclosingType, default: TypeInformation()]
      .events[eventName, default: [EventInformation]()]
      .append(EventInformation(declaration: eventDeclaration))
  }

  public func addSpecial(_ special: SpecialDeclaration,
                         enclosingType: Identifier,
                         callerProtections: [CallerProtection]) {
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
  /// protections is expected.
  public func addFunction(_ functionDeclaration: FunctionDeclaration,
                          enclosingType: RawTypeIdentifier,
                          states: [TypeState],
                          callerProtections: [CallerProtection]) {
    let functionName = functionDeclaration.name

    types[enclosingType, default: TypeInformation()]
      .functions[functionName, default: [FunctionInformation]()]
      .append(FunctionInformation(declaration: functionDeclaration,
                                  typeStates: states,
                                  callerProtections: callerProtections,
                                  isMutating: functionDeclaration.isMutating,
                                  isSignature: false))
  }

  public func removeFunction(_ functionDeclaration: FunctionDeclaration,
                             enclosingType: RawTypeIdentifier,
                             states: [TypeState],
                             callerProtections: [CallerProtection]) {
    if let type: TypeInformation = types[enclosingType],
       let implementations: [FunctionInformation] = type.functions[functionDeclaration.identifier.name] {
      types[enclosingType]?.functions[functionDeclaration.identifier.name]
          = implementations.filter { (info: FunctionInformation) in
        return info.declaration.identifierTypes != functionDeclaration.identifierTypes
                || info.declaration.identifier.name != functionDeclaration.identifier.name
                || info.callerProtections != callerProtections
                || info.typeStates != states
      }
    }
  }

  /// Add an initializer declaration to a type (contract or struct). In the case of a contract, a list of caller
  /// protections is expected.
  public func addInitializer(_ initializerDeclaration: SpecialDeclaration,
                             enclosingType: RawTypeIdentifier,
                             callerProtections: [CallerProtection] = []) {
    types[enclosingType, default: TypeInformation()]
      .initializers
      .append(SpecialInformation(declaration: initializerDeclaration,
                                 callerProtections: callerProtections,
                                 isSignature: false))
  }

  /// Add a function declaration to a type (contract or struct). In the case of a contract, a list of caller
  /// protections is expected.
  public func addFunctionSignature(_ signature: FunctionSignatureDeclaration,
                                   enclosingType: RawTypeIdentifier,
                                   states: [TypeState],
                                   callerProtections: [CallerProtection],
                                   isExternal: Bool) {
    let functionName = signature.identifier.name

    let functionDeclaration = FunctionDeclaration(signature: signature,
                                                  body: [],
                                                  closeBraceToken: .init(kind: .punctuation(.closeBrace),
                                                                         sourceLocation: .DUMMY),
                                                  isExternal: isExternal)

    types[enclosingType, default: TypeInformation()]
      .functions[functionName, default: [FunctionInformation]()]
      .append(FunctionInformation(declaration: functionDeclaration,
                                  typeStates: states,
                                  callerProtections: callerProtections,
                                  isMutating: functionDeclaration.isMutating,
                                  isSignature: true))
  }

  /// Add an initializer declaration to a type (contract or struct). In the case of a contract, a list of caller
  /// protections is expected.
  public func addInitializerSignature(_ initalizerSignature: SpecialSignatureDeclaration,
                                      enclosingType: RawTypeIdentifier,
                                      callerProtections: [CallerProtection] = [],
                                      generated: Bool = false) {

    let specialDeclaration = SpecialDeclaration(signature: initalizerSignature,
                                                body: [],
                                                closeBraceToken: .init(kind: .punctuation(.closeBrace),
                                                                       sourceLocation: .DUMMY),
                                                generated: generated)

    types[enclosingType, default: TypeInformation()]
      .initializers
      .append(SpecialInformation(declaration: specialDeclaration,
                                 callerProtections: callerProtections,
                                 isSignature: true))
  }

  /// Add an initializer declaration to a type (contract or struct). In the case of a contract, a list of caller
  /// protections is expected.
  public func addFallback(_ fallbackDeclaration: SpecialDeclaration,
                          enclosingType: RawTypeIdentifier,
                          callerProtections: [CallerProtection] = []) {
    types[enclosingType, default: TypeInformation()].fallbacks
      .append(SpecialInformation(declaration: fallbackDeclaration,
                                 callerProtections: callerProtections,
                                 isSignature: false))
  }

  /// Add a list of properties to a type.
  func setProperties(_ properties: [Property], enclosingType: RawTypeIdentifier) {
    types[enclosingType]!.orderedProperties = properties.map { $0.identifier.name }
    for property in properties {
      addProperty(property, enclosingType: enclosingType)
    }
  }

  /// Add a property to a type.
  func addProperty(_ property: Property, enclosingType: RawTypeIdentifier) {
    guard let type = types[enclosingType] else {
      fatalError("""
                 Encoutered Property `\(property.identifier.name)': \(property.type?.name ?? "<Unknown>") \
                 on unrecognised type `\(enclosingType)' whilst handling \(property.sourceLocation)
                 """)
    }
    if type.properties[property.identifier.name] == nil {
      types[enclosingType]!.properties[property.identifier.name] = PropertyInformation(property: property)
    }
  }

  /// Add a conformance to a type.
  public func addConformance(_ type: RawTypeIdentifier, conformsTo trait: RawTypeIdentifier) {
    if types[trait] != nil {
      types[type]!.conformances.append(types[trait]!)
    }
  }

  private func externalTraitInitializer(_ externalTrait: TraitDeclaration) -> SpecialSignatureDeclaration {
    return SpecialSignatureDeclaration(
      specialToken: .init(kind: .punctuation(.openBrace),
                          sourceLocation: externalTrait.traitToken.sourceLocation),
      attributes: [],
      modifiers: [],
      mutates: [],
      parameters: [Parameter(identifier: Identifier(identifierToken: Token(kind: .identifier("address"),
                                                    sourceLocation: externalTrait.traitToken.sourceLocation)),
                             type: Type(inferredType: .basicType(.address), identifier: externalTrait.identifier),
                             implicitToken: nil,
                             assignedExpression: nil)],
      prePostConditions: [],
      closeBracketToken: .init(kind:.punctuation(.closeBrace), sourceLocation: externalTrait.traitToken.sourceLocation))
  }

  /// Add a trait to the environment.
  public func addTrait(_ trait: TraitDeclaration) {
    declaredTraits.append(trait.identifier)
    types[trait.identifier.name] = TypeInformation()

    let isExternal: Bool
    if case .external = trait.traitKind.kind {
      isExternal = true

      // We insert a generated constructor for external traits
      let special = externalTraitInitializer(trait)
      addInitializerSignature(special, enclosingType: trait.identifier.name, callerProtections: [],
                              generated: true)
    } else {
      isExternal = false
    }

    for member in trait.members {
      if case .eventDeclaration(let eventDeclaration) = member {
        addEvent(eventDeclaration, enclosingType: trait.identifier.name)
      } else if case .functionDeclaration(let functionDeclaration) = member {
        addFunction(functionDeclaration, enclosingType: trait.identifier.name, states: [], callerProtections: [])
      } else if case .specialDeclaration(let specialDeclaration) = member {
        addSpecial(specialDeclaration, enclosingType: trait.identifier, callerProtections: [])
      } else if case .functionSignatureDeclaration(let signature) = member {
        addFunctionSignature(signature,
                             enclosingType: trait.identifier.name,
                             states: [],
                             callerProtections: [],
                             isExternal: isExternal)
      } else if case .specialSignatureDeclaration(let signature) = member {
        addInitializerSignature(signature, enclosingType: trait.identifier.name, callerProtections: [])
      }
    }
  }

  /// Add a use of an undefined variable.
  public func addUsedUndefinedVariable(_ variable: Identifier, enclosingType: RawTypeIdentifier) {
    let declaration = VariableDeclaration(modifiers: [],
                                          declarationToken: nil,
                                          identifier: variable,
                                          type: Type(inferredType: .errorType, identifier: variable))
    addProperty(.variableDeclaration(declaration), enclosingType: enclosingType)
  }

  /// Set the public initializer for the given contract. A contract should have at most one public initializer.
  public func setPublicInitializer(_ publicInitializer: SpecialDeclaration, for type: RawTypeIdentifier) {
    types[type]!.publicInitializer = publicInitializer
  }

  /// Set the public fallback for the given contract. A contract should have at most one public fallback.
  public func setPublicFallback(_ publicFallback: SpecialDeclaration, for type: RawTypeIdentifier) {
    types[type]!.publicFallback = publicFallback
  }

  // Add function call to call graph
  public func addFunctionCall(caller: String, callee: (String, FunctionDeclaration)) {
    var existingCalls = callGraph[caller] ?? [(String, FunctionDeclaration)]()
    // Avoid having duplicates
    if existingCalls.first(where: { $0.0 == callee.0 }) == nil {
      existingCalls.append(callee)
      callGraph[caller] = existingCalls
    }
  }

  public func addExternalCall(caller: String) {
    functionCallsExternal[caller] = true
  }
}
