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
        }
        return IULIAFunction(functionDeclaration: functionDeclaration, typeIdentifier: contractDeclaration.identifier, capabilityBinding: contractBehaviorDeclaration.capabilityBinding, callerCapabilities: contractBehaviorDeclaration.callerCapabilities, environment: environment)
      }
    }

    let functionsCode = functions.map({ $0.rendered() }).joined(separator: "\n\n").indented(by: 6)

    let publicFunctions = functions.filter { $0.functionDeclaration.isPublic }

    // Create a function selector, to determine which function is called in the Ethereum transaction.
    let functionSelector = IULIAFunctionSelector(functions: publicFunctions)
    let selectorCode = functionSelector.rendered().indented(by: 6)

    // Generate code for each function in the structs.
    let structFunctions = renderStructFunctions().indented(by: 6)

    let initializerBody = renderPublicInitializer()

    // Generate runtime functions.
    let runtimeFunctionsDeclarations = renderRuntimeFunctions().indented(by: 6)

    // Main contract body.
    return """
    pragma solidity ^0.4.21;
    
    contract \(contractDeclaration.identifier.name) {

      \(initializerBody.indented(by: 2))

      function () public payable {
        assembly {
          // Memory address 0x40 holds the next available memory location.
          mstore(0x40, 0x60)

          \(selectorCode)

          // User-defined functions

          \(functionsCode)

          // Struct functions
    
          \(structFunctions)

          // Flint runtime

          \(runtimeFunctionsDeclarations)
        }
      }
    }
    """
  }
  
  func renderStructFunctions() -> String {
    return structDeclarations.map { structDeclaration in
      return IULIAStruct(structDeclaration: structDeclaration, environment: environment).rendered()
    }.joined(separator: "\n\n")
  }
  
  func renderRuntimeFunctions() -> String {
    return IULIARuntimeFunction.allDeclarations.joined(separator: "\n\n")
  }

  func renderPublicInitializer() -> String {
    let (initializerDeclaration, contractBehaviorDeclaration) = findContractPublicInitializer()!

    let capabilityBinding = contractBehaviorDeclaration.capabilityBinding
    let callerCapabilities = contractBehaviorDeclaration.callerCapabilities

    let initializer = IULIAContractInitializer(initializerDeclaration: initializerDeclaration, typeIdentifier: contractDeclaration.identifier, propertiesInEnclosingType: contractDeclaration.variableDeclarations, capabilityBinding: capabilityBinding, callerCapabilities: callerCapabilities, environment: environment, isContractFunction: true).rendered()

    let parameters = initializerDeclaration.parameters.map { parameter in
      let parameterName = parameter.identifier.name.mangled
      return "\(CanonicalType(from: parameter.type.rawType)!.rawValue) \(parameterName)"
      }.joined(separator: ", ")

    return """
    constructor(\(parameters)) public {
      assembly {
        // Memory address 0x40 holds the next available memory location.
        mstore(0x40, 0x60)
    
        \(initializer.indented(by: 4))
        \(renderStructFunctions().indented(by: 4))
        \(renderRuntimeFunctions().indented(by: 4))
      }
    }
    """
  }

  /// Finds the contract's public initializer, if any is declared, and returns the enclosing contract behavior declaration.
  func findContractPublicInitializer() -> (InitializerDeclaration, ContractBehaviorDeclaration)? {
    let result = contractBehaviorDeclarations.flatMap { contractBehaviorDeclaration in
      return contractBehaviorDeclaration.members.compactMap { member -> (InitializerDeclaration, ContractBehaviorDeclaration)? in
        guard case .initializerDeclaration(let initializerDeclaration) = member, initializerDeclaration.isPublic else {
          return nil
        }
        return (initializerDeclaration, contractBehaviorDeclaration)
      }
    }

    guard result.count < 2 else {
      fatalError("Too many initializers")
    }

    return result.first
  }
}
