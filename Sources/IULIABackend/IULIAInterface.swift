//
//  IULIAInterface.swift
//  IULIABackend
//
//  Created by Franklin Schrans on 12/29/17.
//

import AST

struct IULIAInterface {
  var contract: IULIAContract

  func rendered() -> String {
    let functionSignatures = contract.contractBehaviorDeclarations.flatMap { contractBehaviorDeclaration in
      return contractBehaviorDeclaration.functionDeclarations.map { functionDeclaration in
        return render(functionDeclaration)
      }
    }.joined(separator: "\n")

    return """
    interface _Interface\(contract.contractDeclaration.identifier.name) {
      \(functionSignatures.indented(by: 2))
    }
    """
  }

  func render(_ functionDeclaration: FunctionDeclaration) -> String {
    let parameters = functionDeclaration.parameters.map { render($0) }.joined(separator: ",")

    var attributes = functionDeclaration.modifiers.flatMap { modifier in
      switch modifier {
      case .public: return "public"
      default: return nil
      }
    }

    if !functionDeclaration.modifiers.contains(.mutating) {
      attributes.append("constant")
    }

    let attributesCode = attributes.joined(separator: " ")

    let returnCode: String?
    if let resultType = functionDeclaration.resultType {
      returnCode = " returns (\(CanonicalType(from: resultType)!) ret)"
    } else {
      returnCode = ""
    }

    return "function \(functionDeclaration.identifier.name)(\(parameters)) \(attributesCode)\(returnCode ?? "");"
  }

  func render(_ functionParameter: Parameter) -> String {
    return "\(CanonicalType(from: functionParameter.type)!.rawValue) \(functionParameter.identifier.name)"
  }
}
