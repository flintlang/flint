//
//  TokenKind+Literal.swift
//  Lexer
//
//  Created by Hails, Daniel R on 22/08/2018.
//

extension Token.Kind {
  public enum Literal: Equatable {
    case boolean(BooleanLiteral)
    case decimal(DecimalLiteral)
    case string(String)
    case address(String)
  }

  public enum BooleanLiteral: String {
    case `true`
    case `false`
  }

  public enum DecimalLiteral: Equatable {
    case integer(Int)
    case real(Int, Int)
  }

}

extension Token.Kind.Literal: CustomStringConvertible {
  public var description: String {
    switch self {
    case .boolean(let boolean): return boolean.rawValue
    case .decimal(let decimal): return decimal.description
    case .string(let string):   return "literal \"\(string)\""
    case .address(let hex):     return "literal \(hex)"
    }
  }
}

extension Token.Kind.DecimalLiteral: CustomStringConvertible {
  public var description: String {
    switch self {
    case .integer(let integer): return "literal \(integer)"
    case .real(let base, let fractional): return "literal \(base).\(fractional)"
    }
  }
}
