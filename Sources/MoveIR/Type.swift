//
//  Type.swift
//  YUL
//
//  Created by Aurel Bílý on 12/26/18.
//

public enum Type: CustomStringConvertible {
  case bool
  case bytearray
  case u64
  case address
  case `struct`(name: String)
  case resource(name: String)
  case any

  public var description: String {
    switch self {
    case .bool: return "bool"
    case .bytearray: return "bytearray"
    case .u64: return "u64"
    case .address: return "address"
    case .`struct`(let name): return "V#\(name)"
    case .resource(let name): return "&mut R#\(name)"
    case .any: return "__UnknownAnyType<PleaseSee:MoveIR/Type.swift>"
    }
  }
}
