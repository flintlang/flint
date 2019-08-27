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
public indirect enum RawType: Equatable, Hashable {
  case basicType(BasicType)
  case rangeType(RawType)
  case arrayType(RawType)
  case fixedSizeArrayType(RawType, size: Int)
  case dictionaryType(key: RawType, value: RawType)
  case userDefinedType(RawTypeIdentifier)
  case inoutType(RawType)
  case functionType(parameters: [RawType], result: RawType)
  case solidityType(SolidityType)
  case selfType
  case any
  case errorType

  public enum BasicType: RawTypeIdentifier {
    case address = "Address"
    case int = "Int"
    case string = "String"
    case void = "Void"
    case bool = "Bool"
    case event = "Event"

    private static let solidityParallels: [BasicType: SolidityType] = [
      .address: .address,
      .int: .int256,
      .string: .bytes32,
      .bool: .bool
    ]

    public var isIntegral: Bool {
      return self == .int
    }

    public var solidityParallel: RawTypeIdentifier? {
      return BasicType.solidityParallels[self]?.rawValue
    }
  }

  public enum StdlibType: RawTypeIdentifier {
    case wei = "Wei"
  }

  public enum SolidityType: RawTypeIdentifier {
    // Address
    case address = "address"

    // String
    case string = "string"

    // Bool
    case bool = "bool"

    // int
    case int8 = "int8"
    case int16 = "int16"
    case int24 = "int24"
    case int32 = "int32"
    case int40 = "int40"
    case int48 = "int48"
    case int56 = "int56"
    case int64 = "int64"
    case int72 = "int72"
    case int80 = "int80"
    case int88 = "int88"
    case int96 = "int96"
    case int104 = "int104"
    case int112 = "int112"
    case int120 = "int120"
    case int128 = "int128"
    case int136 = "int136"
    case int144 = "int144"
    case int152 = "int152"
    case int160 = "int160"
    case int168 = "int168"
    case int176 = "int176"
    case int184 = "int184"
    case int192 = "int192"
    case int200 = "int200"
    case int208 = "int208"
    case int216 = "int216"
    case int224 = "int224"
    case int232 = "int232"
    case int240 = "int240"
    case int248 = "int248"
    case int256 = "int256"

    // uint
    case uint8 = "uint8"
    case uint16 = "uint16"
    case uint24 = "uint24"
    case uint32 = "uint32"
    case uint40 = "uint40"
    case uint48 = "uint48"
    case uint56 = "uint56"
    case uint64 = "uint64"
    case uint72 = "uint72"
    case uint80 = "uint80"
    case uint88 = "uint88"
    case uint96 = "uint96"
    case uint104 = "uint104"
    case uint112 = "uint112"
    case uint120 = "uint120"
    case uint128 = "uint128"
    case uint136 = "uint136"
    case uint144 = "uint144"
    case uint152 = "uint152"
    case uint160 = "uint160"
    case uint168 = "uint168"
    case uint176 = "uint176"
    case uint184 = "uint184"
    case uint192 = "uint192"
    case uint200 = "uint200"
    case uint208 = "uint208"
    case uint216 = "uint216"
    case uint224 = "uint224"
    case uint232 = "uint232"
    case uint240 = "uint240"
    case uint248 = "uint248"
    case uint256 = "uint256"

    case bytes32 = "bytes32"

    public var isIntegral: Bool {
      switch self {
      case .address:
        return false
      case .string:
        return false
      case .bool:
        return false
      case .bytes32:
        return false
      case .int8, .int16, .int24, .int32, .int40, .int48, .int56, .int64,
           .int72, .int80, .int88, .int96, .int104, .int112, .int120, .int128,
           .int136, .int144, .int152, .int160, .int168, .int176, .int184, .int192,
           .int200, .int208, .int216, .int224, .int232, .int240, .int248, .int256:
        return true
      case .uint8, .uint16, .uint24, .uint32, .uint40, .uint48, .uint56, .uint64,
           .uint72, .uint80, .uint88, .uint96, .uint104, .uint112, .uint120, .uint128,
           .uint136, .uint144, .uint152, .uint160, .uint168, .uint176, .uint184, .uint192,
           .uint200, .uint208, .uint216, .uint224, .uint232, .uint240, .uint248, .uint256:
        return true
      }
    }

    public var basicParallel: RawTypeIdentifier? {
      if isIntegral {
        return BasicType.int.rawValue
      }

      switch self {
      case .address:
        return BasicType.address.rawValue
      case .string:
        return BasicType.string.rawValue
      case .bytes32:
        return BasicType.string.rawValue
      case .bool:
        return BasicType.bool.rawValue
      default:
        return nil
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
    case .userDefinedType(let identifier): return identifier
    case .inoutType(let rawType): return "$inout\(rawType.name)"
    case .selfType: return "Self"
    case .any: return "Any"
    case .errorType: return "Flint$ErrorType"
    case .functionType(let parameters, let result):
      return "(\(parameters.map { $0.name }.joined(separator: ", ")) -> \(result)"
    case .solidityType(let solidityType): return solidityType.rawValue
    }
  }

  public var isBuiltInType: Bool {
    switch self {
    case .basicType, .any, .errorType: return true
    case .arrayType(let element): return element.isBuiltInType
    case .rangeType(let element): return element.isBuiltInType
    case .fixedSizeArrayType(let element, _): return element.isBuiltInType
    case .dictionaryType(let key, let value): return key.isBuiltInType && value.isBuiltInType
    case .inoutType(let element): return element.isBuiltInType
    case .selfType: return false
    case .userDefinedType: return false
    case .functionType: return false
    case .solidityType: return true
    }
  }

  public var isUserDefinedType: Bool {
    return !isBuiltInType
  }

  /// Whether the type is a dynamic type.
  public var isDynamicType: Bool {
    if case .basicType(_) = self {
      return false
    }

    return true
  }

  public var isInout: Bool {
    if case .inoutType(_) = self {
      return true
    }
    return false
  }

  public var isSelfType: Bool {
    if case .inoutType(.selfType) = self {
      return true
    }

    return self == .selfType
  }

  public var isSolidityType: Bool {
    if case .solidityType(_) = self {
      return true
    }

    return false
  }

  public var isCurrencyType: Bool {
    // Iterate until we find a non-inout type
    var actualType: RawType = self
    while case .inoutType(let inoutType) = actualType {
      actualType = inoutType
    }

    if case .userDefinedType(let typeIdentifier) = actualType,
      RawType.StdlibType(rawValue: typeIdentifier) == .wei {
      return true
    }
    return false
  }

  // Strip inoutType for use in type comparisons
  public var stripInout: RawType {
    if case .inoutType(let type) = self {
      return type
    }

    return self
  }

  /// Whether the type is compatible with the given type, i.e., if two expressions of those types can be used
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

  public func isCompatible(with otherType: RawType, in passContext: ASTPassContext) -> Bool {
    if let traitDeclarationContext = passContext.traitDeclarationContext,
      self == .selfType,
      traitDeclarationContext.traitIdentifier.name == otherType.name {
      return true
    }

    return isCompatible(with: otherType)
  }

  public func replacingSelf(with enclosingType: RawTypeIdentifier) -> RawType {
    if isSelfType {
      let selfType: RawType = .userDefinedType(enclosingType)
      return isInout ? .inoutType(selfType) : selfType
    }

    return self
  }

  // Can we reinterpret this type as `other`?
  public func canReinterpret(as other: RawType) -> Bool {
    // If other is basic, we can reinterpret to other if we are basic or solidity
    if case .basicType(let basic) = other {
      // Other is solidity
      if case .solidityType(let solidity) = self {
        return basic.isIntegral && solidity.isIntegral ||
          basic == .string && solidity == .string ||
          basic == .address && solidity == .address ||
          basic == .bool && solidity == .bool
      }

      // Otherwise we need equality of types (basic == basic)
      return self == other
    }

    // Two solidity types
    if case .solidityType(let x) = self,
      case .solidityType(let y) = other {
      // Allow integral types to eachother, but equality otherwise
      return x.isIntegral && y.isIntegral || x == y
    }

    // If other is solidity type, for now we treat this identically to the above
    if other.isSolidityType {
      return other.canReinterpret(as: self)
    }

    return false
  }

}

/// A Flint type.
public struct Type: ASTNode {
  public var rawType: RawType
  public var genericArguments = [Type]()

  public var name: String {
    return rawType.name
  }

  public var isCurrencyType: Bool {
    return rawType.isCurrencyType
  }

  var isSelfType: Bool {
    return rawType.isSelfType
  }

  // Initializers for each kind of raw type.

  public init(identifier: Identifier, genericArguments: [Type] = []) {
    let name = identifier.name
    if let builtInType = RawType.BasicType(rawValue: name) {
      rawType = .basicType(builtInType)
    } else if let solidityType = RawType.SolidityType(rawValue: name) {
      rawType = .solidityType(solidityType)
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

  public init(openSquareBracketToken: Token,
              dictionaryWithKeyType keyType: Type,
              valueType: Type,
              closeSquareBracketToken: Token) {
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
