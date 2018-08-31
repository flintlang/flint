//
//  Type.swift
//  AST
//
//  Created by Hails, Daniel J R on 21/08/2018.
//
import Lexer
import Source
/// The raw representation of an RawType.
public typealias RawTypeIdentifier = String

// A Flint raw type, without a source location.
public indirect enum RawType: Equatable {
  case basicType(BasicType)
  case contractType(RawTypeIdentifier)
  case structType(RawTypeIdentifier)
  case enumType(RawTypeIdentifier)
  case rangeType(RawType)
  case arrayType(RawType)
  case fixedSizeArrayType(RawType, size: Int)
  case dictionaryType(key: RawType, value: RawType)
  case inoutType(RawType)
  case any
  case errorType

  public enum BasicType: RawTypeIdentifier {
    case address = "Address"
    case int = "Int"
    case string = "String"
    case void = "Void"
    case bool = "Bool"
    case event = "Event"

    var isCallerCapabilityType: Bool {
      switch self {
      case .address: return true
      default: return false
      }
    }
  }

  public var name: String {
    switch self {
    case .fixedSizeArrayType(let rawType, size: let size): return "\(rawType.name)[\(size)]"
    case .arrayType(let rawType): return "[\(rawType.name)]"
    case .rangeType(let rawType): return "(\(rawType.name))"
    case .basicType(let builtInType): return "\(builtInType.rawValue)"
    case .dictionaryType(let keyType, let valueType): return "[\(keyType.name): \(valueType.name)]"
    case .inoutType(let rawType): return "$inout\(rawType.name)"
    case .any: return "Any"
    case .errorType: return "Flint$ErrorType"
    case .contractType(let identifier): return "Contract<\(identifier)>"
    case .structType(let identifier): return "Struct<\(identifier)>"
    case .enumType(let identifier): return "Enum<\(identifier)>"
    }
  }

  public var isEventType: Bool {
    return self == .basicType(.event)
  }

  /// Whether the type is a dynamic type.
  public var isDynamicType: Bool {
    if case .basicType(_) = self {
      return false
    }

    return true
  }

  /// Whether the type is compatible with the given type, i.e., if two expressions of those types can be used
  /// interchangeably.
  public func isCompatible(with otherType: RawType) -> Bool {
    if self == .any || otherType == .any { return true }
    guard self != otherType else { return true }

    switch (self, otherType) {
    case (.arrayType(let e1), .arrayType(let e2)):
      return e1.isCompatible(with: e2)
    case (.fixedSizeArrayType(let e1, _), .fixedSizeArrayType(let e2, _)):
      return e1.isCompatible(with: e2)
    case (.fixedSizeArrayType(let e1, _), .arrayType(let e2)):
      return e1.isCompatible(with: e2)
    case (.dictionaryType(let key1, let value1), .dictionaryType(let key2, let value2)):
      return key1.isCompatible(with: key2) && value1.isCompatible(with: value2)
    default: return false
    }
  }
}


/// A Flint type.
public struct Type: ASTNode {
  public var rawType: RawType
  public var genericArguments = [Type]()

  public var name: String {
    return rawType.name
  }

  var isCurrencyType: Bool {
    switch rawType {
    case .structType("Wei"): return true
    default: return false
    }
  }

  // Initializers for each kind of raw type.

  public init(builtIn: Identifier, genericArguments: [Type] = []) throws {
    let name = builtIn.name
    guard let builtInType = RawType.BasicType(rawValue: name) else {
      fatalError("Called init(builtIn: .. ) with identifier that was not built in")
    }
    self.rawType = .basicType(builtInType)
    self.genericArguments = genericArguments
    self.sourceLocation = builtIn.sourceLocation
  }

  public init(contract: Identifier, genericArguments: [Type] = []) {
    self.rawType = .contractType(contract.name)
    self.genericArguments = genericArguments
    self.sourceLocation = contract.sourceLocation
  }

  public init(structure: Identifier, genericArguments: [Type] = []) {
    self.rawType = .structType(structure.name)
    self.genericArguments = genericArguments
    self.sourceLocation = structure.sourceLocation
  }

  public init(enumeration: Identifier) {
    self.rawType = .enumType(enumeration.name)
    self.genericArguments = []
    self.sourceLocation = enumeration.sourceLocation
  }

  public init(ampersandToken: Token, inoutType: Type) {
    rawType = .inoutType(inoutType.rawType)
    sourceLocation = ampersandToken.sourceLocation
  }

  public init(inoutToken: Token, inoutType: Type) {
    rawType = .inoutType(inoutType.rawType)
    sourceLocation = inoutToken.sourceLocation
  }

  public init(openSquareBracketToken: Token, arrayWithElementType type: Type, closeSquareBracketToken: Token) {
    rawType = .arrayType(type.rawType)
    sourceLocation = .spanning(openSquareBracketToken, to: closeSquareBracketToken)
  }

  public init(fixedSizeArrayWithElementType type: Type, size: Int, closeSquareBracketToken: Token) {
    rawType = .fixedSizeArrayType(type.rawType, size: size)
    sourceLocation = .spanning(type, to: closeSquareBracketToken)
  }

  public init(openSquareBracketToken: Token, dictionaryWithKeyType keyType: Type, valueType: Type, closeSquareBracketToken: Token) {
    rawType = .dictionaryType(key: keyType.rawType, value: valueType.rawType)
    sourceLocation = .spanning(openSquareBracketToken, to: closeSquareBracketToken)
  }

  public init(inferredType: RawType, identifier: Identifier) {
    rawType = inferredType
    sourceLocation = identifier.sourceLocation
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation

  public var description: String {
    return name
  }
}
