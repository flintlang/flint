//
//  IRLiteralToken.swift
//  IRGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import Lexer

/// Generates code for a literal token.
struct IRLiteralToken {
  var literalToken: Token

  func rendered() -> String {
    guard case .literal(let literal) = literalToken.kind else {
      fatalError("Unexpected token \(literalToken.kind).")
    }

    switch literal {
    case .boolean(let boolean): return boolean == .false ? "0" : "1"
    case .decimal(.real(let num1, let num2)): return "\(num1).\(num2)"
    case .decimal(.integer(let num)): return "\(num)"
    case .string(let string): return "\"\(string)\""
    case .address(let hex): return hex
    }
  }
}
