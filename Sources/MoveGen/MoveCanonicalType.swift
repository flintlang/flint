//
//  MoveCanonicalType.swift
//  MoveGen
//
//  Created on 30/Jul/2019.
//

import Foundation
import AST

/// A MoveIR type.
enum CanonicalType: CustomStringConvertible {
  case u64
  case address
  case bool
  case bytearray
  case resource(String)
  case `struct`(String)

  init?(from rawType: RawType) {
    switch rawType {
    case .basicType(let builtInType):
      switch builtInType {
      case .address: self = .address
      case .int: self = .u64
      case .bool: self = .bool
      case .string: self = .bytearray
      default:
        print("rawType: \(rawType)")
        return nil
      }
    case .userDefinedType(let id): self = .resource(id)
    case .inoutType(let rawType):
      guard let type = CanonicalType(from: rawType) else { return nil }
      self = type
    // FIXME The collection types are just stub to make the code work
    // and should probably be modified
    case .fixedSizeArrayType(let type, let size):
      self = CanonicalType(from: type)!
    case .arrayType(let type):
      self = CanonicalType(from: type)!
    case .dictionaryType(let key, let value):
      self = CanonicalType(from: key)!
    default:
      print("rawType': \(rawType)")
      return nil
    }
  }

  var description: String {
    switch self {
    case .address: return "address"
    case .u64: return "u64"
    case .bool: return "bool"
    case .bytearray: return "bytearray"
    case .resource(let name): return "R#\(name)"
    case .struct(let name): return "V#\(name)"
    }
  }
}
