//
//  Token.swift
//  Parser
//
//  Created by Franklin Schrans on 12/19/17.
//

/// A lexical token valid in Flint.
public struct Token: Equatable, SourceEntity {
  /// The kind of token.
  public var kind: Kind

  /// The source location of the token.
  public var sourceLocation: SourceLocation

  public init(kind: Kind, sourceLocation: SourceLocation) {
    self.kind = kind
    self.sourceLocation = sourceLocation
  }
}

extension Token {
  public enum Kind: Equatable {
    public enum Punctuation: String {
      case openBrace          = "{"
      case closeBrace         = "}"
      case openSquareBracket  = "["
      case closeSquareBracket = "]"
      case colon              = ":"
      case doubleColon        = "::"
      case openBracket        = "("
      case closeBracket       = ")"
      case arrow              = "->"
      case leftArrow          = "<-"
      case comma              = ","
      case semicolon          = ";"
      case doubleSlash        = "//"
      case openAngledBracket  = "<"
      case closeAngledBracket = ">"

      case plus             = "+"
      case overflowingPlus  = "&+"
      case minus            = "-"
      case overflowingMinus = "&-"
      case times            = "*"
      case overflowingTimes = "&*"
      case power            = "**"
      case divide     = "/"
      case dot        = "."
      case dotdot     = ".."
      case ampersand  = "&"

      // Assignments

      case equal  = "="
      case plusEqual = "+="
      case minusEqual = "-="
      case timesEqual = "*="
      case divideEqual = "/="
      
      // Ranges
      case halfOpenRange = "..<"
      case closedRange = "..."
      
      // Comparisons
      case doubleEqual = "=="
      case notEqual = "!="
      case lessThanOrEqual = "<="
      case greaterThanOrEqual = ">="
      case or = "||"
      case and = "&&"

      static var allBinaryOperators: [Punctuation] {
        return [
          .plus, .overflowingPlus, .minus, .overflowingMinus, .times, .overflowingTimes, .power, .divide, .equal, .plusEqual, .minusEqual, .timesEqual, .divideEqual, .dot,
          .closeAngledBracket, .lessThanOrEqual, .openAngledBracket, .greaterThanOrEqual, .doubleEqual, .notEqual,
          .or, .and
        ]
      }
      public static var allBinaryOperatorsByIncreasingPrecedence: [Punctuation] {
        return allBinaryOperators.sorted { $0.precedence < $1.precedence }
      }

      public var isAssignment: Bool {
        return [.equal, .plusEqual, .minusEqual, .timesEqual, .divideEqual].contains(self)
      }

      public var isBooleanOperator: Bool {
        return [.doubleEqual, .notEqual, .lessThanOrEqual, .greaterThanOrEqual, .or, .and, .openAngledBracket, .closeAngledBracket].contains(self)
      }

      var precedence: Int {
        switch self {
        case .equal, .plusEqual, .minusEqual, .timesEqual, .divideEqual: return 10
        case .or: return 11
        case .and: return 12
        case .closeAngledBracket, .lessThanOrEqual, .openAngledBracket, .greaterThanOrEqual, .doubleEqual, .notEqual: return 15
        case .plus, .overflowingPlus: return 20
        case .minus, .overflowingMinus: return 20
        case .times, .overflowingTimes: return 30
        case .divide: return 30
        case .power: return 31
        case .ampersand: return 35
        case .dot: return 40
        default: return 0
        }
      }

      public var operatorAssignmentOperator: Punctuation? {
        switch self {
        case .plusEqual: return .plus
        case .minusEqual: return .minus
        case .timesEqual: return .times
        case .divideEqual: return .divide
        default: return nil
        }
      }
    }

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

    // Newline
    case newline

    // Keywords
    case contract
    case `struct`
    case `var`
    case `let`
    case `func`
    case `init`
    case `mutating`
    case `return`
    case `public`
    case `if`
    case `else`
    case `for`
    case `in`
    case `self`
    case implicit
    case `inout`

    // Punctuation
    case punctuation(Punctuation)

    // Declaration attribute
    case attribute(String)

    // Identifiers
    case identifier(String)

    // Literals
    case literal(Literal)
  }
}

extension Token.Kind: CustomStringConvertible {
  public var description: String {
    switch self {
    case .newline: return "\\\n"
    case .contract: return "contract"
    case .struct: return "struct"
    case .var: return "var"
    case .let: return "let"
    case .func: return "func"
    case .init: return "init"
    case .self: return "self"
    case .implicit: return "implicit"
    case .inout: return "inout"
    case .mutating: return "mutating"
    case .return: return "return"
    case .public: return "public"
    case .if: return "if"
    case .else: return "else"
    case .for: return "for"
    case .in: return "in"
    case .punctuation(let punctuation): return punctuation.rawValue
    case .attribute(let attribute): return "@\(attribute)"
    case .identifier(let identifier): return "identifier \"\(identifier)\""
    case .literal(let literal): return literal.description
    }
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
