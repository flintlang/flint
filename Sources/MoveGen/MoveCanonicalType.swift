//
//  MoveCanonicalType.swift
//  MoveGen
//
//  Created on 30/Jul/2019.
//

import Foundation
import AST
import MoveIR

/// A MoveIR type.
enum CanonicalType: CustomStringConvertible {
  case u64
  case address
  case bool
  case bytearray
  case resource(String)
  case `struct`(String)

  init?(from rawType: RawType, environment: Environment? = nil) {
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
    case .userDefinedType(let id):
      if rawType.isCurrencyType || rawType.isContractType(environment: environment) {
        self = .resource(id)
      } else {
        self = .struct(id)
      }
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

  public var irType: MoveIR.`Type` {
    switch self {
    case .address: return .address
    case .u64: return .u64
    case .bool: return .bool
    case .bytearray: return .bytearray
    case .`struct`(let name): return .`struct`(name: name)
    case .resource(let name): return .resource(name: name)
    }
  }

  public var description: String {
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
