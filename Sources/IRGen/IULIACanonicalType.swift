//
//  IRCanonicalType.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/29/17.
//

import AST

enum CanonicalType: String {
  case uint256
  case address
  case bytes32

  init?(from rawType: Type.RawType) {
    switch rawType {
    case .builtInType(let builtInType):
      switch builtInType {
      case .address: self = .address
      case .int, .bool, .wei: self = .uint256
      case .string: self = .bytes32
      default: return nil
      }
    default: return nil
    }
  }
}
