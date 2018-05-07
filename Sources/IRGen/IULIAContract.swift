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
    let structFunctions = structDeclarations.map { structDeclaration in
      return IULIAStruct(structDeclaration: structDeclaration, environment: environment).rendered()
    }.joined(separator: "\n\n").indented(by: 6)

    let initializerBody = renderPublicInitializer()

    // Generate runtime functions.
    let runtimeFunctionsDeclarations = IULIARuntimeFunction.allDeclarations.joined(separator: "\n\n").indented(by: 6)

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
    
          \(structFunctions)

          // Flint runtime

          \(runtimeFunctionsDeclarations)
        }
      }
    }
    """
  }

  func renderPublicInitializer() -> String {
    let initializerDeclaration: InitializerDeclaration

    // The contract behavior declaration the initializer resides in.
    let contractBehaviorDeclaration: ContractBehaviorDeclaration?

    if let (publicInitializer, contractBehaviorDeclaration_) = findContractPublicInitializer() {
      initializerDeclaration = publicInitializer
      contractBehaviorDeclaration = contractBehaviorDeclaration_
    } else {
      // If there is not public initializer defined, synthesize one.
      initializerDeclaration = synthesizeInitializer()
      contractBehaviorDeclaration = nil
    }

    let capabilityBinding = contractBehaviorDeclaration?.capabilityBinding
    let callerCapabilities = contractBehaviorDeclaration?.callerCapabilities ?? []

    let initializer = IULIAContractInitializer(initializerDeclaration: initializerDeclaration, typeIdentifier: contractDeclaration.identifier, propertiesInEnclosingType: contractDeclaration.variableDeclarations, capabilityBinding: capabilityBinding, callerCapabilities: callerCapabilities, environment: environment, isContractFunction: true).rendered()

    let parameters = initializerDeclaration.parameters.map { parameter in
      let parameterName = parameter.identifier.name.mangled
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

  func synthesizeInitializer() -> InitializerDeclaration {
    let sourceLocation = contractDeclaration.sourceLocation

    return InitializerDeclaration(initToken: Token(kind: .init, sourceLocation: sourceLocation), attributes: [], modifiers: [Token(kind: .public, sourceLocation: sourceLocation)], parameters: [], closeBracketToken: Token(kind: .punctuation(.closeBracket), sourceLocation: sourceLocation), body: [], closeBraceToken: Token(kind: .punctuation(.closeBrace), sourceLocation: sourceLocation), scopeContext: ScopeContext(localVariables: []))
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
