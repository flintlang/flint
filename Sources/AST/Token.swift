//
//  Token.swift
//  Parser
//
//  Created by Franklin Schrans on 12/19/17.
//

import Foundation

public enum Token {
  public enum BinaryOperator: String {
    case plus   = "+"
    case minus  = "-"
    case times = "*"
    case divide = "/"
    case equal  = "="
    case dot    = "."

    case lessThan = "<"
    case lessThanOrEqual = "<="
    case greaterThan = ">"
    case greaterThanOrEqual = ">="
    
    static let all: [BinaryOperator] = [.plus, .minus, .times, .divide, .equal, .dot, .lessThan, .lessThanOrEqual, .greaterThan, .greaterThanOrEqual]
    public static let allByIncreasingPrecedence = {
      return all.sorted { $0.precedence < $1.precedence }
    }()
    
    var precedence: Int {
      switch self {
      case .equal: return 10
      case .lessThan: return 15
      case .lessThanOrEqual: return 15
      case .greaterThan: return 15
      case .greaterThanOrEqual: return 15
      case .plus: return 20
      case .minus: return 20
      case .times: return 30
      case .divide: return 30
      case .dot: return 40
      }
    }
  }
  
  public enum Punctuation: String {
    case openBrace       = "{"
    case closeBrace      = "}"
    case colon           = ":"
    case doubleColon     = "::"
    case openBracket     = "("
    case closeBracket    = ")"
    case arrow           = "->"
    case comma           = ","
    case semicolon       = ";"
  }

  public enum Literal: Equatable {
    case boolean(BooleanLiteral)
    case decimal(DecimalLiteral)
    case string(String)

    public static func ==(lhs: Token.Literal, rhs: Token.Literal) -> Bool {
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

    public static func ==(lhs: Token.DecimalLiteral, rhs: Token.DecimalLiteral) -> Bool {
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
  case `var`
  case `func`
  case `mutating`
  case `return`
  case `public`
  case `if`
  case `else`
  
  // Operators
  case binaryOperator(BinaryOperator)
  case minus
  
  // Punctuation
  case punctuation(Punctuation)
  
  // Identifiers
  case identifier(String)

  // Literals
  case literal(Literal)
}

extension Token: Equatable {
  public static func ==(lhs: Token, rhs: Token) -> Bool {
    switch (lhs, rhs) {
    case (.newline, .newline): return true
    case (.contract, .contract): return true
    case (.var, .var): return true
    case (.func, .func): return true
    case (.mutating, .mutating): return true
    case (.return, .return): return true
    case (.public, .public): return true
    case (.if, .if): return true
    case (.else, .else): return true
    case (.binaryOperator(let operator1), .binaryOperator(let operator2)): return operator1 == operator2
    case (.punctuation(let punctuation1), .punctuation(let punctuation2)): return punctuation1 == punctuation2
    case (.identifier(let identifier1), .identifier(let identifier2)): return identifier1 == identifier2
    case (.literal(let lhsLiteral), .literal(let rhsLiteral)): return lhsLiteral == rhsLiteral
    default:
      return false
    }
  }
}
