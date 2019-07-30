//
//  MoveCanonicalType.swift
//  MoveGen
//
//  Created on 30/Jul/2019.
//

import AST

/// An MoveIR type.
enum CanonicalType: String {
  case uint256
  case address
  case bytes32

  init?(from rawType: RawType) {
    switch rawType {
    case .basicType(let builtInType):
      switch builtInType {
      case .address: self = .address
      case .int, .bool: self = .uint256
      case .string: self = .bytes32
      default: return nil
      }
    case .userDefinedType: self = .uint256
    case .inoutType(let rawType):
      guard let type = CanonicalType(from: rawType) else { return nil }
      self = type
    default: return nil
    }
  }
}
