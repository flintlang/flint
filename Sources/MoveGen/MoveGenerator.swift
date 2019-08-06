//
// Created by matthewross on 29/07/19.
//

import Foundation
import AST

public struct MoveGenerator {
  var topLevelModule: TopLevelModule
  var environment: Environment

  public init(ast topLevelModule: TopLevelModule, environment: Environment) {
    self.topLevelModule = topLevelModule
    self.environment = environment
  }

  public func generateCode() -> String {

    var contracts = [MoveContract]()

    // Find the contract behavior declarations associated with each contract.
    for case .contractDeclaration(let contractDeclaration) in topLevelModule.declarations {
      let behaviorDeclarations: [ContractBehaviorDeclaration] = topLevelModule.declarations
          .compactMap { declaration in
            switch declaration {
            case .contractBehaviorDeclaration(let contractBehaviorDeclaration): return contractBehaviorDeclaration
            default: return nil } }
          .filter { $0.contractIdentifier.name == contractDeclaration.identifier.name }

      // Find the struct declarations.
      let structDeclarations = topLevelModule.declarations.compactMap { declaration -> StructDeclaration? in
        guard case .structDeclaration(let structDeclaration) = declaration else { return nil }
        return structDeclaration
      }

      let contract = MoveContract(contractDeclaration: contractDeclaration,
                                contractBehaviorDeclarations: behaviorDeclarations,
                                structDeclarations: structDeclarations,
                                environment: environment)
      contracts.append(contract)
    }

    // Generate a IR contract and a IR interface.
    // The interface is used for exisiting Solidity tools such as Truffle and Remix to interpret Flint code as
    // Solidity code.

    return contracts.map { $0.rendered() }.joined(separator: "\n")
  }
}
