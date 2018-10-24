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
  case stdlibType(StdlibType)
  case rangeType(RawType)
  case arrayType(RawType)
  case fixedSizeArrayType(RawType, size: Int)
  case dictionaryType(key: RawType, value: RawType)
  case userDefinedType(RawTypeIdentifier)
  case inoutType(RawType)
  case functionType(parameters: [RawType], result: RawType)
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
  }

  public enum StdlibType: RawTypeIdentifier {
    case wei = "Wei"
  }

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
    case .selfType: return "Self"
    case .any: return "Any"
    case .errorType: return "Flint$ErrorType"
    case .functionType(let parameters, let result):
      return "(\(parameters.map { $0.name }.joined(separator: ", ")) -> \(result)"
    }
  }

  public var isBuiltInType: Bool {
    switch self {
    case .basicType, .stdlibType, .any, .errorType: return true
    case .arrayType(let element): return element.isBuiltInType
    case .rangeType(let element): return element.isBuiltInType
    case .fixedSizeArrayType(let element, _): return element.isBuiltInType
    case .dictionaryType(let key, let value): return key.isBuiltInType && value.isBuiltInType
    case .inoutType(let element): return element.isBuiltInType
    case .selfType: return false
    case .userDefinedType: return false
    case .functionType: return false
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

  public func isCompatible(with otherType: RawType, in passContext: ASTPassContext) -> Bool {
    if let traitDeclarationContext = passContext.traitDeclarationContext,
      self == .selfType,
      traitDeclarationContext.traitIdentifier.name == otherType.name {
      return true
    }

    return isCompatible(with: otherType)
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
    case .stdlibType(.wei): return true
    default: return false
    }
  }

  var isSelfType: Bool {
    return rawType.isSelfType
  }

  // Initializers for each kind of raw type.

  public init(identifier: Identifier, genericArguments: [Type] = []) {
    let name = identifier.name
    if let builtInType = RawType.BasicType(rawValue: name) {
      rawType = .basicType(builtInType)
    } else if let stdlibType = RawType.StdlibType(rawValue: name) {
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
