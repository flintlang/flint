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
indirect enum CanonicalType: CustomStringConvertible {
  case u64
  case address
  case bool
  case bytearray
  case resource(String)
  case `struct`(String)
  // case reference(CanonicalType) Not Yet Used
  case mutableReference(CanonicalType)

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
    case .userDefinedType(let identifier):
      /*if environment?.isExternalTraitDeclared(identifier) ?? false {
        self = .address
        return
      }*/
      self =  rawType.isCurrencyType || (environment?.isContractDeclared(identifier) ?? false) ?
        .resource(identifier) : .struct(identifier)
    case .inoutType(let rawType):
      guard let type = CanonicalType(from: rawType, environment: environment) else { return nil }

      /*if case .userDefinedType(let identifier) = rawType,
        environment?.isExternalTraitDeclared(identifier) ?? false {
        self = .address
        return
      }*/
      self = .mutableReference(type)
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

  public var description: String {
    switch self {
    case .address: return "CanonicalType.address"
    case .u64: return "CanonicalType.u64"
    case .bool: return "CanonicalType.bool"
    case .bytearray: return "CanonicalType.bytearray"
    case .resource(let name): return "CanonicalType.R#\(name)"
    case .struct(let name): return "CanonicalType.V#\(name)"
    case .mutableReference(let type): return "CanonicalType.&mut \(type)"
    }
  }

  public func render(functionContext: FunctionContext) -> MoveIR.`Type` {
    switch self {
    case .address: return .address
    case .u64: return .u64
    case .bool: return .bool
    case .bytearray: return .bytearray
    case .`struct`(let name): return .`struct`(name: "Self.\(name)")
    case .resource(let name):
      if functionContext.enclosingTypeName == name {
        return .resource(name: "Self.T")
      }
      return .resource(name: "\(name).T")
    case .mutableReference(let type):
      /*
      var typeIdentifier: String?
      switch type {
      case .resource(let identifier):
        typeIdentifier = identifier
      case .`struct`(let identifier):
        typeIdentifier = identifier
      case .mutableReference(let canonicalType):
        fatalError("Mutable ref to mutable ref")
      default:
        break
      }
      if typeIdentifier != nil,
        functionContext.environment.isExternalTraitDeclared(typeIdentifier!) {
        return .address
      }*/
      //return type.render(functionContext: functionContext)
      return .mutableReference(to: type.render(functionContext: functionContext))
    }

  }
}
