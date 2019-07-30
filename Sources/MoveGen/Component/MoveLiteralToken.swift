//
//  MoveLiteralToken.swift
//  MoveGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import Lexer
import MoveIR

/// Generates code for a literal token.
struct MoveLiteralToken {
  var literalToken: Token

  func rendered() -> MoveIR.Literal {
    guard case .literal(let literal) = literalToken.kind else {
      fatalError("Unexpected token \(literalToken.kind).")
    }

    switch literal {
    case .boolean(let boolean): return boolean == .true ? .bool(true) : .bool(false)
    case .decimal(.real(let num1, let num2)): return Literal.decimal(num1, num2)
    case .decimal(.integer(let num)): return .num(num)
    case .string(let string): return .string(string)
    case .address(let hex): return .hex(hex)
    }
  }
}
