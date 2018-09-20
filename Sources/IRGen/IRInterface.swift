//
//  IRInterface.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/29/17.
//

import AST

/// A IR interface for Flint contracts, to help tools such as Remix and Truffle interpret Flint code as Solidity.
struct IRInterface {
  var contract: IRContract
  var environment: Environment

  func rendered() -> String {
    let functionSignatures = contract.contractBehaviorDeclarations.flatMap { contractBehaviorDeclaration in
      return contractBehaviorDeclaration.members.compactMap { member in
        switch member {
        case .functionDeclaration(let functionDeclaration):
          return render(functionDeclaration)
        case .specialDeclaration(_):
          return ""
          // Rendering initializers/fallback is not supported yet.
        }
      }
    }.joined(separator: "\n")

    let events = environment.events(in: contract.contractDeclaration.identifier.name)
    let eventDeclarations = events.map { event -> String in
      let parameters = event.declaration.variableDeclarations.map { variable in
        return "\(CanonicalType(from: variable.type.rawType)!.rawValue) \(variable.identifier.name)"
      }.joined(separator: ",")

      return "event \(event.declaration.identifier.name)(\(parameters));"
    }.joined(separator: "\n")

    return """
    interface _Interface\(contract.contractDeclaration.identifier.name) {
      \(functionSignatures.indented(by: 2))
      \(eventDeclarations.indented(by: 2))
    }
    """
  }

  func render(_ functionDeclaration: FunctionDeclaration) -> String? {
    guard functionDeclaration.isPublic else { return nil }

    let parameters = functionDeclaration.explicitParameters.map { render($0) }.joined(separator: ", ")

    var attribute = ""

    if !functionDeclaration.isMutating, !functionDeclaration.containsEventCall(environment: environment, contractIdentifier: contract.contractDeclaration.identifier) {
      attribute = "view "
    }

    if functionDeclaration.isPayable {
      attribute = "payable "
    }

    let returnCode: String
    if let resultType = functionDeclaration.signature.resultType {
      returnCode = " returns (\(CanonicalType(from: resultType.rawType)!) ret)"
    } else {
      returnCode = ""
    }

    return "function \(functionDeclaration.identifier.name)(\(parameters)) \(attribute)external\(returnCode);"
  }

  func render(_ functionParameter: Parameter) -> String {
    return "\(CanonicalType(from: functionParameter.type.rawType)!.rawValue) \(functionParameter.identifier.name.mangled)"
  }
}

fileprivate extension FunctionDeclaration {
  func containsEventCall(environment: Environment, contractIdentifier: Identifier) -> Bool {
    for statement in body {
      if case .emitStatement(_) = statement {
        return true
      }
    }

    return false
  }
}
