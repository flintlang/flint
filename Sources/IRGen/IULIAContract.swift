//
//  IULIAContract.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/28/17.
//

import AST

/// Generates code for a contract.
struct IULIAContract {
  var contractDeclaration: ContractDeclaration
  var contractBehaviorDeclarations: [ContractBehaviorDeclaration]
  var structDeclarations: [StructDeclaration]
  var environment: Environment

  init(contractDeclaration: ContractDeclaration, contractBehaviorDeclarations: [ContractBehaviorDeclaration], structDeclarations: [StructDeclaration], environment: Environment) {
    self.contractDeclaration = contractDeclaration
    self.contractBehaviorDeclarations = contractBehaviorDeclarations
    self.structDeclarations = structDeclarations
    self.environment = environment
  }

  func rendered() -> String {
    // Generate code for each function in the contract.
    let functions = contractBehaviorDeclarations.flatMap { contractBehaviorDeclaration in
      return contractBehaviorDeclaration.members.compactMap { member -> IULIAFunction? in
        guard case .functionDeclaration(let functionDeclaration) = member else {
          return nil
          // Rendering initializers is not supported yet.
        }
        return IULIAFunction(functionDeclaration: functionDeclaration, typeIdentifier: contractDeclaration.identifier, capabilityBinding: contractBehaviorDeclaration.capabilityBinding, callerCapabilities: contractBehaviorDeclaration.callerCapabilities, environment: environment)
      }
    }

    let functionsCode = functions.map({ $0.rendered() }).joined(separator: "\n\n").indented(by: 6)

    // Create a function selector, to determine which function is called in the Ethereum transaction.
    let functionSelector = IULIAFunctionSelector(functions: functions)
    let selectorCode = functionSelector.rendered().indented(by: 6)

    // Generate code for each function in the structs.
    let structFunctions = structDeclarations.flatMap { structDeclaration in
      return structDeclaration.functionDeclarations.compactMap { functionDeclaration in
        return IULIAFunction(functionDeclaration: functionDeclaration, typeIdentifier: structDeclaration.identifier, environment: environment)
      }
    }

    // TODO: Generate code for initializers too.

    let structsFunctionsCode = structFunctions.map({ $0.rendered() }).joined(separator: "\n\n").indented(by: 6)
    let initializerBody = renderInitializers()

    var index = 0
    var propertyDeclarations = [String]()

    for property in contractDeclaration.variableDeclarations where !property.type.rawType.isEventType {
      let rawType = property.type.rawType

      for canonicalType in storageCanonicalTypes(for: rawType) {
        propertyDeclarations.append("\(canonicalType) _flintStorage\(index);")
        index += 1
      }
    }

    let propertyDeclarationsCode = propertyDeclarations.joined(separator: "\n")

    // Generate runtime functions.
    let runtimeFunctionsDeclarations = IULIARuntimeFunction.all.map { $0.declaration }.joined(separator: "\n\n").indented(by: 6)

    // Main contract body.
    return """
    pragma solidity ^0.4.21;
    
    contract \(contractDeclaration.identifier.name) {

      \(propertyDeclarationsCode.indented(by: 2))

      \(initializerBody.indented(by: 2))

      function () public payable {
        assembly {
          \(selectorCode)

          // User-defined functions

          \(functionsCode)

          // Struct functions
    
          \(structsFunctionsCode)

          // Flint runtime

          \(runtimeFunctionsDeclarations)
        }
      }
    }
    """
  }

  func renderInitializers() -> String {
    return contractBehaviorDeclarations.flatMap { contractBehaviorDeclaration in
      return contractBehaviorDeclaration.members.compactMap { member -> String? in
        guard case .initializerDeclaration(let initializerDeclaration) = member else {
          return nil
        }

        let initializer = IULIAInitializer(initializerDeclaration: initializerDeclaration, typeIdentifier: contractDeclaration.identifier, propertiesInEnclosingType: contractDeclaration.variableDeclarations, capabilityBinding: contractBehaviorDeclaration.capabilityBinding, callerCapabilities: contractBehaviorDeclaration.callerCapabilities, environment: environment, isContractFunction: true).rendered()

        let parameters = initializerDeclaration.parameters.map { parameter in
          let parameterName = Mangler.mangleName(parameter.identifier.name)
          return "\(CanonicalType(from: parameter.type.rawType)!.rawValue) \(parameterName)"
        }.joined(separator: ", ")

        // TODO: Assign default values set at property declarations.

        return """
        constructor(\(parameters)) public {
          assembly {
            \(initializer.indented(by: 4))
          }
        }
        """
      }
    }.joined(separator: "\n")
  }

//    // Generate an initializer which takes in the 256-bit values in storage.
//    let initializerParameters = contractDeclaration.variableDeclarations.filter { $0.type.rawType.isBasicType && !$0.type.rawType.isEventType && $0.assignedExpression == nil }
//    let initializerParameterList = initializerParameters.map { "\(CanonicalType(from: $0.type.rawType)!.rawValue) \($0.identifier.name)" }.joined(separator: ", ")
//    var initializerBody = initializerParameters.map { parameter in
//      let offset = environment.propertyOffset(for: parameter.identifier.name, enclosingType: contractDeclaration.identifier.name)!
//      return "_flintStorage\(offset) = \(parameter.identifier.name);"
//      }.joined(separator: "\n")
//
//    let defaultValueAssignments = contractDeclaration.variableDeclarations.compactMap { declaration -> String? in
//      guard let assignedExpression = declaration.assignedExpression else { return nil }
//      let offset = environment.propertyOffset(for: declaration.identifier.name, enclosingType: contractDeclaration.identifier.name)!
//      guard case .literal(let literalToken) = assignedExpression else {
//        fatalError("Non-literal default values are not supported yet")
//      }
//      return "_flintStorage\(offset) = \(IULIALiteralToken(literalToken: literalToken).rendered());"
//    }
//
//    initializerBody += "\n" + defaultValueAssignments.joined(separator: "\n")
//    return """
//    function \(contractDeclaration.identifier.name)(\(initializerParameterList)) public {
//      \(initializerBody.indented(by: 2))
//    }
//    """
//  }

  /// The list of canonical types for the given type. Fixed-size arrays of size `n` will result in a list of `n`
  /// canonical types.
  public func storageCanonicalTypes(for type: Type.RawType) -> [String] {
    switch type {
    case .builtInType(_), .arrayType(_), .dictionaryType(_, _):
      return [type.canonicalElementType!.rawValue]
    case .fixedSizeArrayType(let rawType, let elementCount):
      return [String](repeating: rawType.canonicalElementType!.rawValue, count: elementCount)
    case .errorType: fatalError()

    case .userDefinedType(let identifier):
      return environment.properties(in: identifier).flatMap { property -> [String] in
        let type = environment.type(of: property, enclosingType: identifier)!
        return storageCanonicalTypes(for: type)
      }
    case .inoutType(_): fatalError()
    }
  }
}

fileprivate extension Type.RawType {

  /// The canonical type of self, or its element's canonical type in the case of arrays and dictionaries.
  var canonicalElementType: CanonicalType? {
    switch self {
    case .builtInType(_): return CanonicalType(from: self)
    case .errorType: return CanonicalType(from: self)
    case .dictionaryType(_, _): return .uint256 // Nothing is stored in that property.
    case .arrayType(_): return .uint256 // The number of elements is stored.
    case .fixedSizeArrayType(let elementType, _): return CanonicalType(from: elementType)
    case .userDefinedType(_): fatalError()
    case .inoutType(_): fatalError()
    }
  }
}
