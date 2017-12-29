//
//  IULIACanonicalType.swift
//  IULIABackend
//
//  Created by Franklin Schrans on 12/29/17.
//

import AST

enum CanonicalType: String {
  case uint256
  case address

  init?(from type: Type) {
    switch type.name {
    case "Ether": self = .uint256
    case "Address": self = .address
    default: return nil
    }
  }
}
