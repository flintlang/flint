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
  var context: Context

  var storage = ContractStorage()

  init(contractDeclaration: ContractDeclaration, contractBehaviorDeclarations: [ContractBehaviorDeclaration], context: Context) {
    self.contractDeclaration = contractDeclaration
    self.contractBehaviorDeclarations = contractBehaviorDeclarations
    self.context = context

    for variableDeclaration in contractDeclaration.variableDeclarations {
      switch variableDeclaration.type.rawType {
      case .arrayType(_):
        storage.allocate(variableDeclaration.type.rawType.size, for: variableDeclaration.identifier.name)
      default:
        storage.addProperty(variableDeclaration.identifier.name)
      }
    }
  }

  func rendered() -> String {
    let functions = contractBehaviorDeclarations.flatMap { contractBehaviorDeclaration in
      return contractBehaviorDeclaration.functionDeclarations.map { functionDeclaration in
        return IULIAFunction(functionDeclaration: functionDeclaration, contractIdentifier: contractDeclaration.identifier, callerCapabilities: contractBehaviorDeclaration.callerCapabilities, contractStorage: storage, context: context)
      }
    }

    let functionsCode = functions.map({ $0.rendered() }).joined(separator: "\n\n").indented(by: 6)

    let functionSelector = IULIAFunctionSelector(functions: functions)
    let selectorCode = functionSelector.rendered().indented(by: 6)

    let runtimeFunctionsDeclarations = IULIARuntimeFunction.all.map { $0.declaration }.joined(separator: "\n\n").indented(by: 6)

    return """
    contract \(contractDeclaration.identifier.name) {

      function \(contractDeclaration.identifier.name)() public {
      }

      function () public payable {
        assembly {
          \(selectorCode)

          // User-defined functions

          \(functionsCode)

          // Flint runtime

          \(runtimeFunctionsDeclarations)
        }
      }
    }
    """
  }
}
