//
//  IULIAContract.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/28/17.
//

import AST

struct IULIAContract {
  var contractDeclaration: ContractDeclaration
  var contractBehaviorDeclarations: [ContractBehaviorDeclaration]
  var structDeclarations: [StructDeclaration]
  var environment: Environment

  var storage = ContractStorage()

  init(contractDeclaration: ContractDeclaration, contractBehaviorDeclarations: [ContractBehaviorDeclaration], structDeclarations: [StructDeclaration], environment: Environment) {
    self.contractDeclaration = contractDeclaration
    self.contractBehaviorDeclarations = contractBehaviorDeclarations
    self.structDeclarations = structDeclarations
    self.environment = environment

    for variableDeclaration in contractDeclaration.variableDeclarations {
      switch variableDeclaration.type.rawType {
      case .fixedSizeArrayType(_):
        storage.allocate(environment.size(of: variableDeclaration.type.rawType), for: variableDeclaration.identifier.name)
      default:
        storage.addProperty(variableDeclaration.identifier.name)
      }
    }
  }

  func rendered() -> String {
    let functions = contractBehaviorDeclarations.flatMap { contractBehaviorDeclaration in
      return contractBehaviorDeclaration.functionDeclarations.map { functionDeclaration in
        return IULIAFunction(functionDeclaration: functionDeclaration, typeIdentifier: contractDeclaration.identifier, capabilityBinding: contractBehaviorDeclaration.capabilityBinding, callerCapabilities: contractBehaviorDeclaration.callerCapabilities, contractStorage: storage, environment: environment)
      }
    }

    let functionsCode = functions.map({ $0.rendered() }).joined(separator: "\n\n").indented(by: 6)

    let functionSelector = IULIAFunctionSelector(functions: functions)
    let selectorCode = functionSelector.rendered().indented(by: 6)

    let structFunctions = structDeclarations.flatMap { structDeclaration in
      return structDeclaration.functionDeclarations.flatMap { functionDeclaration in
        return IULIAFunction(functionDeclaration: functionDeclaration, typeIdentifier: structDeclaration.identifier, contractStorage: storage, environment: environment)
      }
    }

    let structsFunctionsCode = structFunctions.map({ $0.rendered() }).joined(separator: "\n\n").indented(by: 6)

    let initializerParameters = contractDeclaration.variableDeclarations.filter { $0.type.rawType.isBasicType && !$0.type.rawType.isEventType }
    let initializerParameterList = initializerParameters.map { "\(CanonicalType(from: $0.type.rawType)!.rawValue) \($0.identifier.name)" }.joined(separator: ", ")
    let initializerBody = initializerParameters.map { parameter in
      return "_flintStorage\(storage.offset(for: parameter.identifier.name)) = \(parameter.identifier.name);"
    }.joined(separator: "\n")

    var index = 0
    var propertyDeclarations = [String]()

    for property in contractDeclaration.variableDeclarations where !property.type.rawType.isEventType {
      let rawType = property.type.rawType
      let rawTypeSize = environment.size(of: rawType)
      for _ in (0..<rawTypeSize) {
        propertyDeclarations.append("\(rawType.canonicalElementType?.rawValue ?? "uint256") _flintStorage\(index);")
        index += 1
      }
    }

    let propertyDeclarationsCode = propertyDeclarations.joined(separator: "\n")

    let runtimeFunctionsDeclarations = IULIARuntimeFunction.all.map { $0.declaration }.joined(separator: "\n\n").indented(by: 6)

    return """
    pragma solidity ^0.4.19;
    
    contract \(contractDeclaration.identifier.name) {

      \(propertyDeclarationsCode.indented(by: 2))

      function \(contractDeclaration.identifier.name)(\(initializerParameterList)) public {
        \(initializerBody.indented(by: 4))
      }

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
    }
  }
}
