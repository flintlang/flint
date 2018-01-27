//
//  Token.swift
//  Parser
//
//  Created by Franklin Schrans on 12/19/17.
//

public struct Token: Equatable, SourceEntity {
  public var kind: Kind
  public var sourceLocation: SourceLocation

  public init(kind: Kind, sourceLocation: SourceLocation) {
    self.kind = kind
    self.sourceLocation = sourceLocation
  }

  public static func ==(lhs: Token, rhs: Token) -> Bool {
    return lhs.kind == rhs.kind && lhs.sourceLocation == rhs.sourceLocation
  }
}

extension Token {
  public enum Kind {
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

      case plus   = "+"
      case minus  = "-"
      case times = "*"
      case divide = "/"
      case dot    = "."

      // Assignments

      case equal  = "="
      case plusEqual = "+="
      case minusEqual = "-="
      case timesEqual = "*="
      case divideEqual = "/="

      case lessThanOrEqual = "<="
      case greaterThanOrEqual = ">="

      static var allBinaryOperators: [Punctuation] { return [.plus, .minus, .times, .divide, .equal, .plusEqual, .minusEqual, .timesEqual, .divideEqual, .dot, .closeAngledBracket, .lessThanOrEqual, .openAngledBracket, .greaterThanOrEqual] }
      public static var allBinaryOperatorsByIncreasingPrecedence: [Punctuation] {
        return allBinaryOperators.sorted { $0.precedence < $1.precedence }
      }

      public var isAssignment: Bool {
        return [.equal, .plusEqual, .minusEqual, .timesEqual, .divideEqual].contains(self)
      }

      var precedence: Int {
        switch self {
        case .equal, .plusEqual, .minusEqual, .timesEqual, .divideEqual: return 10
        case .closeAngledBracket, .lessThanOrEqual, .openAngledBracket, .greaterThanOrEqual: return 15
        case .plus: return 20
        case .minus: return 20
        case .times: return 30
        case .divide: return 30
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

      public static func ==(lhs: Literal, rhs: Literal) -> Bool {
        switch (lhs, rhs) {
        case (.boolean(let lhsLiteral), .boolean(let rhsLiteral)): return lhsLiteral == rhsLiteral
        case (.decimal(let lhsLiteral), .decimal(let rhsLiteral)): return lhsLiteral == rhsLiteral
        case (.string(let lhsLiteral), .string(let rhsLiteral)): return lhsLiteral == rhsLiteral
        default: return false
        }
      }
    }

    public enum BooleanLiteral: String {
      case `true`
      case `false`
    }

    public enum DecimalLiteral: Equatable {
      case integer(Int)
      case real(Int, Int)

      public static func ==(lhs: DecimalLiteral, rhs: DecimalLiteral) -> Bool {
        switch (lhs, rhs) {
        case (.integer(let lhsNum), .integer(let rhsNum)): return lhsNum == rhsNum
        case (.real(let lhsNum1, let lhsNum2), .real(let rhsNum1, let rhsNum2)): return lhsNum1 == rhsNum1 && lhsNum2 == rhsNum2
        default: return false
        }
      }
    }

    // Newline
    case newline

    // Keywords
    case contract
    case `struct`
    case `var`
    case `func`
    case `mutating`
    case `return`
    case `public`
    case `if`
    case `else`
    case `self`
    case implicit

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

extension Token.Kind: Equatable {
  public static func ==(lhs: Token.Kind, rhs: Token.Kind) -> Bool {
    switch (lhs, rhs) {
    case (.newline, .newline): return true
    case (.contract, .contract): return true
    case (.struct, .struct): return true
    case (.var, .var): return true
    case (.func, .func): return true
    case (.self, .self): return true
    case (.implicit, .implicit): return true
    case (.mutating, .mutating): return true
    case (.return, .return): return true
    case (.public, .public): return true
    case (.if, .if): return true
    case (.else, .else): return true
    case (.punctuation(let punctuation1), .punctuation(let punctuation2)): return punctuation1 == punctuation2
    case (.attribute(let lhsAttribute), .attribute(let rhsAttribute)): return lhsAttribute == rhsAttribute
    case (.identifier(let identifier1), .identifier(let identifier2)): return identifier1 == identifier2
    case (.literal(let lhsLiteral), .literal(let rhsLiteral)): return lhsLiteral == rhsLiteral
    default:
      return false
    }
  }
}

extension Token.Kind: CustomStringConvertible {
  public var description: String {
    switch self {
    case .newline: return "\\\n"
    case .contract: return "contract"
    case .struct: return "struct"
    case .var: return "var"
    case .func: return "func"
    case .self: return "self"
    case .implicit: return "implicit"
    case .mutating: return "mutating"
    case .return: return "return"
    case .public: return "public"
    case .if: return "if"
    case .else: return "else"
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
    case .string(let string): return "literal \"\(string)\""
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

