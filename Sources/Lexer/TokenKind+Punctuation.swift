//
//  TokenKind+Punctuation.swift
//  Lexer
//
//  Created by Hails, Daniel R on 22/08/2018.
//

extension Token.Kind {
  public enum Punctuation: String {
    case openBrace          = "{"
    case closeBrace         = "}"
    case openSquareBracket  = "["
    case closeSquareBracket = "]"
    case colon              = ":"
    case doubleColon        = "::"
    case openBracket        = "("
    case closeBracket       = ")"
    case at                 = "@"
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
    case percent    = "%"
    case dot        = "."
    case dotdot     = ".."
    case ampersand  = "&"
    case bang       = "!"
    case question   = "?"

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
        .plus, .overflowingPlus, .minus, .overflowingMinus, .times, .overflowingTimes, .power, .divide, .percent, .equal,
        .plusEqual, .minusEqual, .timesEqual, .divideEqual, .dot,

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
      return [
        .doubleEqual, .notEqual, .lessThanOrEqual, .greaterThanOrEqual,
        .or, .and, .openAngledBracket, .closeAngledBracket
        ].contains(self)
    }

    var precedence: Int {
      switch self {
      case .equal, .plusEqual, .minusEqual, .timesEqual, .divideEqual: return 10
      case .or: return 11
      case .and: return 12
      case .closeAngledBracket, .openAngledBracket,
           .lessThanOrEqual, .greaterThanOrEqual, .doubleEqual, .notEqual:
        return 15
      case .plus, .overflowingPlus: return 20
      case .minus, .overflowingMinus: return 20
      case .times, .overflowingTimes: return 30
      case .divide, .percent: return 30
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
}
