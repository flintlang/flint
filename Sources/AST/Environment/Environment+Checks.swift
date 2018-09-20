//
//  Environment+Checks.swift
//  AST
//
//  Created by Hails, Daniel R on 22/08/2018.
//
import Source

extension Environment {
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
  public func conflictingFunctionDeclaration(for function: FunctionDeclaration, in type: RawTypeIdentifier) -> Identifier? {
    var contractFunctions = [Identifier]()

    if isContractDeclared(type) {
      // Contract functions do not support overloading.
      contractFunctions = types[type]!.allFunctions[function.name]?.filter({ !$0.isSignature }).map { $0.declaration.identifier } ?? []
    }

    if let conflict = conflictingDeclaration(of: function.identifier, in: contractFunctions + declaredStructs + declaredContracts) {
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

  // If the number of functions is greater than 1 (the signature of the trait) then there must be a conflict
  public func conflictingTraitSignatures(for type: RawTypeIdentifier) -> [String : [FunctionInformation]] {
    guard let typeInfo = types[type] else {
      return [:]
    }
    return typeInfo.traitFunctions.filter{ (name, functions) in
      functions.count > 1 && functions.contains(where: { $0.declaration.signature != functions.first!.declaration.signature})
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
        for conform in conforming {
          if conform.declaration.signature != signature.declaration.signature {
            notImplemented.append(conform)
          }
        }
      }
    }
    return notImplemented
  }

  public func undefinedInitialisers(in enclosingType: Identifier) -> [SpecialInformation] {
    let typeInfo = types[enclosingType.name]!
    if let conforming = typeInfo.initializers.filter({ !$0.isSignature }).first { // Compatibility check
      if let signature = typeInfo.allInitialisers.filter({ $0.isSignature }).first,
        conforming.declaration.signature != signature.declaration.signature {
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
