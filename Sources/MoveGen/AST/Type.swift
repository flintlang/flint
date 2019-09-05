//
//  Type.swift
//  MoveGen
//
//  Created on 28/08/2019.
//

import AST

extension RawType {
  public func isExternalContract(environment: Environment) -> Bool {
    var internalRawType: RawType = self
    while case .inoutType(let inoutType) = internalRawType {
      internalRawType = inoutType
    }
    if case .userDefinedType(let typeIdentifier) = internalRawType {
      return environment.isExternalTraitDeclared(typeIdentifier)
          && !(environment.types[typeIdentifier].flatMap { (information: TypeInformation) in
        information.isExternalStruct
      } ?? false)
    }
    return false
  }
}

extension TypeInformation {
  var isExternalStruct: Bool {
    return decorators?
        .contains(where: { $0.identifier.name == "data" || $0.identifier.name == "resource" }) ?? false
  }
}
