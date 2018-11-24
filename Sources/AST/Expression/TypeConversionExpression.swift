//
//  TypeConversionExpression.swift
//  AST
//
//  Created by Nik on 14/11/2018.
//

import Source
import Lexer

public struct TypeConversionExpression: ASTNode {
  public enum Kind: CustomStringConvertible {
    // Equivalent to Swift's `as` type conversion.
    //   Calls a matching initialiser in order to convert between types
    //   in a user-defined manner.
    case coerce
    // Equivalent to Swift's `as!` type conversion.
    //   Reinterprets the value as the desired type with compiler-defined
    //   compatibility checks. If conversion fails, program should crash.
    case cast
    // Equivalent to Switft's `as?` type conversion.
    //   Identical to above except that an optional value is returned should
    //   the compatibility check fail.
    case castOptional

    public var description: String {
      switch self {
      case .coerce:
        return "as"
      case .cast:
        return "as!"
      case .castOptional:
        return "as?"
      }
    }
  }

  public var expression: Expression
  public var asToken: Token
  public var type: Type
  public var kind: Kind

  public init(expression: Expression, asToken: Token, kind: Kind, type: Type) {
    self.expression = expression
    self.asToken = asToken
    self.kind = kind
    self.type = type
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return .spanning(expression, to: type)
  }

  public var description: String {
    let symbol: String
    switch kind {
    case .coerce:
      symbol = ""
    case .cast:
      symbol = "!"
    case .castOptional:
      symbol = "?"
    }

    return "\(expression.description) \(symbol.description) \(type.description)"
  }
}
