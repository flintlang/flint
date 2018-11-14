//
//  IRCodeGenerator.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/28/17.
//

import AST

/// Generates code for a Flint AST.
public struct IRCodeGenerator {
  var topLevelModule: TopLevelModule
  var environment: Environment

  public init(topLevelModule: TopLevelModule, environment: Environment) {
    self.topLevelModule = topLevelModule
    self.environment = environment
  }

  public func generateCode() -> String {
    var contracts = [IRContract]()
    var interfaces = [IRInterface]()

    // Find the contract behavior declarations associated with each contract.
    for case .contractDeclaration(let contractDeclaration) in topLevelModule.declarations {
      let behaviorDeclarations: [ContractBehaviorDeclaration] = topLevelModule.declarations.compactMap { declaration in
        guard case .contractBehaviorDeclaration(let contractBehaviorDeclaration) = declaration else {
          return nil
        }

        guard contractBehaviorDeclaration.contractIdentifier.name == contractDeclaration.identifier.name else {
          return nil
        }

        return contractBehaviorDeclaration
      }

      // Find the struct declarations.
      let structDeclarations = topLevelModule.declarations.compactMap { declaration -> StructDeclaration? in
        guard case .structDeclaration(let structDeclaration) = declaration else { return nil }
        return structDeclaration
      }

      let contract = IRContract(contractDeclaration: contractDeclaration,
                                contractBehaviorDeclarations: behaviorDeclarations,
                                structDeclarations: structDeclarations,
                                environment: environment)
      contracts.append(contract)
      interfaces.append(IRInterface(contract: contract, environment: environment))
    }

    // Generate a IR contract and a IR interface.
    // The interface is used for exisiting Solidity tools such as Truffle and Remix to interpret Flint code as
    // Solidity code.

    let renderedContracts = contracts.map({ $0.rendered() }).joined(separator: "\n")
    let renderedInterfaces = interfaces.map({ $0.rendered() }).joined(separator: "\n")

    return renderedContracts + "\n" + renderedInterfaces
  }
}
