//
//  Token.swift
//  Lexer
//
//  Created by Franklin Schrans on 12/19/17.
//
import Source

/// A lexical token valid in Flint.
public struct Token: Equatable, SourceEntity, CustomStringConvertible {
  /// The kind of token.
  public var kind: Kind

  public init(kind: Kind, sourceLocation: SourceLocation) {
    self.kind = kind
    self.sourceLocation = sourceLocation
  }

  // MARK: - Kind
  public enum Kind: Equatable, CustomStringConvertible {
    // Newline
    case newline

    // Punctuation
    case punctuation(Punctuation)

    // Identifiers
    case identifier(String)

    // Literals
    case literal(Literal)

    // Keywords
    case contract, `enum`, `case`, `struct`, `func`, event, trait
    case `init`, fallback
    case `public`, visible, mutates, `mutating`, pre, post, invariant, external
    case `return`, returns, become, `try`, `emit`, call
    case `if`, `else`, `for`, `in`
    case `self`, selfType
    case implicit, `inout`
    case `var`, `let`
    case `catch`, `do`, `is`
    case `as`

    public var description: String {
      switch self {
      case .newline: return "\\\n"
      case .contract: return "contract"
      case .struct: return "struct"
      case .enum: return "enum"
      case .case: return "case"
      case .event: return "event"
      case .trait: return "trait"
      case .var: return "var"
      case .let: return "let"
      case .func: return "func"
      case .`init`: return "init"
      case .fallback: return "fallback"
      case .pre: return "pre"
      case .post: return "post"
      case .invariant: return "invariant"
      case .self: return "self"
      case .selfType: return "Self"
      case .implicit: return "implicit"
      case .inout: return "inout"
      case .mutates: return "mutates"
      case .mutating: return "mutating"
      case .external: return "external"
      case .return: return "return"
      case .returns: return "returns"
      case .become: return "become"
      case .emit: return "emit"
      case .call: return "call"
      case .public: return "public"
      case .visible: return "visible"
      case .if: return "if"
      case .else: return "else"
      case .for: return "for"
      case .in: return "in"
      case .try: return "try"
      case .catch: return "catch"
      case .do: return "do"
      case .is: return "is"
      case .as: return "as"
      case .punctuation(let punctuation): return punctuation.rawValue
      case .identifier(let identifier): return "identifier \"\(identifier)\""
      case .literal(let literal): return literal.description
      }
    }

  }

  // MARK: - CustomStringConvertible
  public var description: String {
    return kind.description
  }

  // MARK: - SourceEntity
  public var sourceLocation: SourceLocation
}

public extension Token {
  public static let DUMMY = Token(kind: .public, sourceLocation: .DUMMY)
}
