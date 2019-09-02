//
//  MoveCanonicalType.swift
//  MoveGen
//
//  Created on 30/Jul/2019.
//

import Foundation
import AST
import MoveIR
import Diagnostic

/// A MoveIR type.
indirect enum CanonicalType: CustomStringConvertible {
  case u64
  case address
  case bool
  case bytearray
  case resource(String)
  case `struct`(String)
  case external(String, CanonicalType)
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
        Diagnostics.add(Diagnostic(severity: .warning,
                                   sourceLocation: nil,
                                   message: "Could not detect basic type for `\(rawType)'"))
        return nil
      }

    case .userDefinedType(let identifier):
      if let environment = environment,
         CanonicalType.isResourceType(rawType, identifier: identifier, environment: environment) {
        self = .resource(identifier)
      } else if let environment = environment,
                rawType.isExternalContract(environment: environment) {
        self = .address
      } else if environment?.isExternalTraitDeclared(identifier) ?? false,
                let type: TypeInformation = environment?.types[identifier] {
        if type.decorators?.contains(where: { $0.identifier.name == "resource" }) ?? false {
          self = .external(identifier, .resource("T"))
        } else {
          self = .external(identifier, .`struct`("T"))
        }
      } else if let environment = environment,
              environment.isEnumDeclared(identifier),
              let type: TypeInformation = environment.types[identifier],
              let value: AST.Expression = type.properties.values.first?.property.value {
        self = CanonicalType(from: environment.type(of: value,
                                                    enclosingType: identifier,
                                                    scopeContext: ScopeContext()))!
      } else {
        self = .struct(identifier)
      }
    case .inoutType(let rawType):
      guard let type = CanonicalType(from: rawType, environment: environment) else { return nil }
      self = .mutableReference(type)
    // FIXME The collection types are just stub to make the code work
    // and should probably be modified
    case .fixedSizeArrayType(let type, _):
      self = CanonicalType(from: type)!
    case .arrayType(let type):
      self = CanonicalType(from: type)!
    case .dictionaryType(let key, _):
      self = CanonicalType(from: key)!
    default:
      Diagnostics.add(Diagnostic(severity: .warning,
                                 sourceLocation: nil,
                                 message: "Could not detect type for `\(rawType)'"))
      return nil
    }
  }

  private static func isResourceType(_ rawType: AST.RawType,
                                     identifier: RawTypeIdentifier,
                                     environment: Environment) -> Bool {
    return rawType.isCurrencyType || environment.isContractDeclared(identifier)
  }

  public var description: String {
    switch self {
    case .address: return "CanonicalType.address"
    case .u64: return "CanonicalType.u64"
    case .bool: return "CanonicalType.bool"
    case .bytearray: return "CanonicalType.bytearray"
    case .resource(let name): return "CanonicalType.Resource.\(name)"
    case .struct(let name): return "CanonicalType.Struct.\(name)"
    case .mutableReference(let type): return "CanonicalType.&mut \(type)"
    case .external(let module, let type): return "CanonicalType.External(\(module), \(type))"
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
      return .mutableReference(to: type.render(functionContext: functionContext))
    case .external(let module, let type):
      switch type {
      case .resource(let name): return .resource(name: "\(module).\(name)")
      case .`struct`(let name): return .`struct`(name: "\(module).\(name)")
      default: fatalError("Only external structs and resources are allowed")
      }
    }
  }
}
