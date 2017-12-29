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
        return IULIAFunction(functionDeclaration: functionDeclaration, callerCapabilities: contractBehaviorDeclaration.callerCapabilities, propertyMap: propertyMap)
      }
    }

    let functionsCode = functions.map({ $0.rendered() }).joined(separator: "\n\n").indented(by: 6)

    let functionSelector = IULIAFunctionSelector(functions: functions)
    let selectorCode = functionSelector.rendered().indented(by: 6)

    let utilFunctionsDeclarations = IULIAUtilFunction.all.map { $0.declaration }.joined(separator: "\n\n").indented(by: 6)

    return """
    contract \(contractDeclaration.identifier.name) {

      function \(contractDeclaration.identifier.name)() public {
      }

      function () public payable {
        assembly {
          \(selectorCode)

          // User-defined functions

          \(functionsCode)

          // Util functions

          \(utilFunctionsDeclarations)
        }
      }
    }
    """
  }
}
