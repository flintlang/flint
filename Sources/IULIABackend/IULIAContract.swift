//
//  IULIAContract.swift
//  IULIABackend
//
//  Created by Franklin Schrans on 12/28/17.
//

import AST

struct IULIAContract {
  var contractDeclaration: ContractDeclaration
  var contractBehaviorDeclarations: [ContractBehaviorDeclaration]

  var propertyMap = [String: Int]()

  init(contractDeclaration: ContractDeclaration, contractBehaviorDeclarations: [ContractBehaviorDeclaration]) {
    self.contractDeclaration = contractDeclaration
    self.contractBehaviorDeclarations = contractBehaviorDeclarations

    var index = 0
    for variableDeclaration in contractDeclaration.variableDeclarations {
      propertyMap[variableDeclaration.identifier.name] = index
      index += 1
    }
  }

  func rendered() -> String {
    let functions = contractBehaviorDeclarations.flatMap { contractBehaviorDeclaration in
      return contractBehaviorDeclaration.functionDeclarations.map { functionDeclaration in
        return IULIAFunction(functionDeclaration: functionDeclaration, callerCapabilities: contractBehaviorDeclaration.callerCapabilities).rendered()
      }
    }

    let functionsCode = functions.joined(separator: "\n")

    return """
    contract \(contractDeclaration.identifier.name) {

      function \(contractDeclaration.identifier.name) public {
      }

      function () public payable {
        assembly {
          \(functionsCode)
        }
      }
    }
    """
  }
}
