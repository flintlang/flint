//
//  IRCanonicalType.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/29/17.
//

import AST

/// An EVM type.
enum CanonicalType: String {
  case uint256
  case address
  case bytes32

  init?(from rawType: Type.RawType) {
    switch rawType {
    case .basicType(let builtInType):
      switch builtInType {
      case .address: self = .address
      case .int, .bool: self = .uint256
      case .string: self = .bytes32
      default: return nil
      }
    case .userDefinedType(_): self = .uint256
    case .inoutType(let rawType):
      guard let type = CanonicalType(from: rawType) else { return nil }
      self = type
    default: return nil
    }
  }
}
