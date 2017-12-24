//
//  Token.swift
//  Parser
//
//  Created by Franklin Schrans on 12/19/17.
//

import Foundation

public enum Token {
  
  public enum BinaryOperator: Character {
    case plus   = "+"
    case minus  = "-"
    case equal  = "="
    case dot    = "."
    
    static let all: [BinaryOperator] = [.plus, .minus, .equal, .dot]
    static let allByIncreasingPrecedence = {
      return all.sorted { $0.precedence < $1.precedence }
    }()
    
    var precedence: Int {
      switch self {
      case .plus: return 20
      case .minus: return 20
      case .equal: return 10
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
  
  // Keywords
  case contract
  case `var`
  case `func`
  case `mutating`
  case `return`
  case `public`
  
  // Operators
  case binaryOperator(BinaryOperator)
  case minus
  
  // Punctuation
  case punctuation(Punctuation)
  
  // Identifiers
  case identifier(String)

  // Literals
  case literal(Literal)

  static let syntaxMap: [String: Token] = [
    "contract": .contract,
    "var": .var,
    "func": .func,
    "mutating": .mutating,
    "return": .return,
    "public": .public,
    "+": .binaryOperator(.plus),
    "-": .binaryOperator(.minus),
    "=": .binaryOperator(.equal),
    ".": .binaryOperator(.dot),
    "{": .punctuation(.openBrace),
    "}": .punctuation(.closeBrace),
    ":": .punctuation(.colon),
    "::": .punctuation(.doubleColon),
    "(": .punctuation(.openBracket),
    ")": .punctuation(.closeBracket),
    "->": .punctuation(.arrow),
    ",": .punctuation(.comma),
    ";": .punctuation(.semicolon),
    "true": .literal(.boolean(.true)),
    "false": .literal(.boolean(.false))
  ]
  
  static func splitOnPunctuation(string: String) -> [String] {
    var components = [String]()
    var acc = ""

    var inStringLiteral = false
    
    for char in string {
      if char == "\"" {
        inStringLiteral = !inStringLiteral
        acc += String(char)
      } else if inStringLiteral {
        acc += String(char)
      } else if CharacterSet.alphanumerics.contains(char.unicodeScalars.first!) {
        acc += String(char)
      } else {
        if !acc.isEmpty {
          components.append(acc)
          acc = ""
        }
        
        if let last = components.last {
          if last == ":", char == ":" {
            components[components.endIndex.advanced(by: -1)] = "::"
            continue
          } else if last == "-", char == ">" {
            components[components.endIndex.advanced(by: -1)] = "->"
            continue
          }
        }
        
        components.append(String(char))
      }
    }
    
    components.append(acc)
    return components.filter { !$0.isEmpty }
  }
  
  static func tokenize(string: String) -> [Token] {
    let components = splitOnPunctuation(string: string)

    var tokens = [Token]()

    for component in components {
      if CharacterSet.whitespacesAndNewlines.contains(component.unicodeScalars.first!) {
        continue
      } else if let token = syntaxMap[component] {
        tokens.append(token)
      } else if let num = Int(component) {
        let lastTwoTokens = tokens[tokens.count-2..<tokens.count]
        if case .literal(.decimal(.integer(let base))) = lastTwoTokens.first!, lastTwoTokens.last! == .binaryOperator(.dot) {
          tokens[tokens.count-2] = .literal(.decimal(.real(base, num)))
          tokens.removeLast()
        } else {
          tokens.append(.literal(.decimal(.integer(num))))
        }
      } else if let first = component.first, let last = component.last, first == "\"", first == last {
        tokens.append(.literal(.string(String(component[(component.index(after: component.startIndex)..<component.index(before: component.endIndex))]))))
      } else {
        tokens.append(.identifier(component))
      }
    }

    return tokens
  }
}

extension Token: Equatable {
  public static func ==(lhs: Token, rhs: Token) -> Bool {
    switch (lhs, rhs) {
    case (.contract, .contract): return true
    case (.var, .var): return true
    case (.func, .func): return true
    case (.mutating, .mutating): return true
    case (.return, .return): return true
    case (.public, .public): return true
    case (.binaryOperator(let operator1), .binaryOperator(let operator2)): return operator1 == operator2
    case (.punctuation(let punctuation1), .punctuation(let punctuation2)): return punctuation1 == punctuation2
    case (.identifier(let identifier1), .identifier(let identifier2)): return identifier1 == identifier2
    case (.literal(let lhsLiteral), .literal(let rhsLiteral)): return lhsLiteral == rhsLiteral
    default:
      return false
    }
  }
}
