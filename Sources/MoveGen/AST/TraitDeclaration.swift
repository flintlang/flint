//
// Created by matthewross on 31/08/19.
//

import Foundation
import AST

extension TraitDeclaration {
  var moduleAddress: String? {
    guard let argument: FunctionArgument = decorators.first(where: { $0.identifier.name == "module" })?.arguments[0],
          let name = argument.identifier?.name,
          name == "address",
          case .literal(let token) = argument.expression,
          case .literal(.address(let address)) = token.kind else {
      return nil
    }
    return address
  }

  var isModule: Bool {
    return decorators.contains(where: { $0.identifier.name == "module" })
  }

  var associatedModule: String? {
    guard let argument = decorators.first(where: { $0.identifier.name == "associated" })?.arguments[0],
          let name = argument.identifier?.name,
          name == "",
          case .identifier(let identifier) = argument.expression else {
      return nil
    }
    return identifier.name
  }

  var isStruct: Bool {
    return decorators.contains(where: { $0.identifier.name == "data" })
  }
}
