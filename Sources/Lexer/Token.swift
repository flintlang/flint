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

    // Declaration attribute
    case attribute(String)

    // Identifiers
    case identifier(String)

    // Literals
    case literal(Literal)

    // Keywords
    case contract, `enum`, `case`, `struct`, `func`, `init`, `mutating`
    case `return`, become, `public`, `if`, `else`, `for`, `in`, `self`, `try`
    case implicit, `inout`, fallback
    case `var`, `let`

    public var description: String {
      switch self {
      case .newline: return "\\\n"
      case .contract: return "contract"
      case .struct: return "struct"
      case .enum: return "enum"
      case .case: return "case"
      case .var: return "var"
      case .let: return "let"
      case .func: return "func"
      case .init: return "init"
      case .fallback: return "fallback"
      case .self: return "self"
      case .implicit: return "implicit"
      case .inout: return "inout"
      case .mutating: return "mutating"
      case .return: return "return"
      case .become: return "become"
      case .public: return "public"
      case .if: return "if"
      case .else: return "else"
      case .for: return "for"
      case .in: return "in"
      case .try: return "try"
      case .punctuation(let punctuation): return punctuation.rawValue
      case .attribute(let attribute): return "@\(attribute)"
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
