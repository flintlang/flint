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

    // Create a function selector, to determine which function is called in the Ethereum transaction.
    let functionSelector = IULIAFunctionSelector(functions: functions)
    let selectorCode = functionSelector.rendered().indented(by: 6)

    // Generate code for each function in the structs.
    let structFunctions = structDeclarations.flatMap { structDeclaration in
      return structDeclaration.functionDeclarations.compactMap { functionDeclaration in
        return IULIAFunction(functionDeclaration: functionDeclaration, typeIdentifier: structDeclaration.identifier, environment: environment)
      }
    }

    let structsFunctionsCode = structFunctions.map({ $0.rendered() }).joined(separator: "\n\n").indented(by: 6)
    let initializerBody = renderPublicInitializers()

    // Generate runtime functions.
    let runtimeFunctionsDeclarations = IULIARuntimeFunction.all.map { $0.declaration }.joined(separator: "\n\n").indented(by: 6)

    // Main contract body.
    return """
    pragma solidity ^0.4.21;
    
    contract \(contractDeclaration.identifier.name) {

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

  func renderPublicInitializers() -> String {
    return contractBehaviorDeclarations.flatMap { contractBehaviorDeclaration in
      return contractBehaviorDeclaration.members.compactMap { member -> String? in
        guard case .initializerDeclaration(let initializerDeclaration) = member, initializerDeclaration.isPublic else {
          return nil
        }

        let initializer = IULIAInitializer(initializerDeclaration: initializerDeclaration, typeIdentifier: contractDeclaration.identifier, propertiesInEnclosingType: contractDeclaration.variableDeclarations, capabilityBinding: contractBehaviorDeclaration.capabilityBinding, callerCapabilities: contractBehaviorDeclaration.callerCapabilities, environment: environment, isContractFunction: true).rendered()

        let parameters = initializerDeclaration.parameters.map { parameter in
          let parameterName = Mangler.mangleName(parameter.identifier.name)
          return "\(CanonicalType(from: parameter.type.rawType)!.rawValue) \(parameterName)"
        }.joined(separator: ", ")

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
}
