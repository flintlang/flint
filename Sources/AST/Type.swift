//
//  Type.swift
//  flintc
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

/// A Flint type.
public struct Type: SourceEntity {
  /// A Flint raw type, without a source location.
  public indirect enum RawType: Equatable {
    case basicType(BasicType)
    case stdlibType(StdlibType)
    case rangeType(RawType)
    case arrayType(RawType)
    case fixedSizeArrayType(RawType, size: Int)
    case dictionaryType(key: RawType, value: RawType)
    case userDefinedType(RawTypeIdentifier)
    case inoutType(RawType)
    case any
    case errorType

    public var name: String {
      switch self {
      case .fixedSizeArrayType(let rawType, size: let size): return "\(rawType.name)[\(size)]"
      case .arrayType(let rawType): return "[\(rawType.name)]"
      case .rangeType(let rawType): return "(\(rawType.name))"
      case .basicType(let builtInType): return "\(builtInType.rawValue)"
      case .stdlibType(let type): return "\(type.rawValue)"
      case .dictionaryType(let keyType, let valueType): return "[\(keyType.name): \(valueType.name)]"
      case .userDefinedType(let identifier): return identifier
      case .inoutType(let rawType): return "$inout\(rawType.name)"
      case .any: return "Any"
      case .errorType: return "Flint$ErrorType"
      }
    }

    public var isBuiltInType: Bool {
      switch self {
      case .basicType(_), .stdlibType(_), .any, .errorType: return true
      case .arrayType(let element): return element.isBuiltInType
      case .rangeType(let element): return element.isBuiltInType
      case .fixedSizeArrayType(let element, _): return element.isBuiltInType
      case .dictionaryType(let key, let value): return key.isBuiltInType && value.isBuiltInType
      case .inoutType(let element): return element.isBuiltInType
      case .userDefinedType(_): return false
      }
    }

    public var isUserDefinedType: Bool {
      return !isBuiltInType
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
    public func isCompatible(with otherType: Type.RawType) -> Bool {
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

  public enum BasicType: String {
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

  public enum StdlibType: String {
    case wei = "Wei"
  }

  public var rawType: RawType
  public var genericArguments = [Type]()
  public var sourceLocation: SourceLocation

  public var name: String {
    return rawType.name
  }

  var isCurrencyType: Bool {
    switch rawType {
    case .stdlibType(.wei): return true
    default: return false
    }
  }

  // Initializers for each kind of raw type.

  public init(identifier: Identifier, genericArguments: [Type] = []) {
    let name = identifier.name
    if let builtInType = BasicType(rawValue: name) {
      rawType = .basicType(builtInType)
    } else if let stdlibType = StdlibType(rawValue: name) {
      rawType = .stdlibType(stdlibType)
    } else {
      rawType = .userDefinedType(name)
    }
    self.genericArguments = genericArguments
    self.sourceLocation = identifier.sourceLocation
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

  public init(inferredType: Type.RawType, identifier: Identifier) {
    rawType = inferredType
    sourceLocation = identifier.sourceLocation
  }
}
