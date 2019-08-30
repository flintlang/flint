//
//  Type.swift
//  MoveGen
//
//  Created on 28/08/2019.
//

import AST

extension RawType {
  public func isExternalTraitType(environment: Environment) -> Bool {
    var internalRawType: RawType = self
    while case .inoutType(let inoutType) = internalRawType {
      internalRawType = inoutType
    }
    if case .userDefinedType(let typeIdentifier) = internalRawType {
      return environment.isExternalTraitDeclared(typeIdentifier)
    }

    return false
  }
}
