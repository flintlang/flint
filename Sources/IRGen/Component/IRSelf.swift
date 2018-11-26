//
//  IRSelf.swift
//  IRGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import Lexer
import YUL
/// Generates code for a "self" expression.
struct IRSelf {
  var selfToken: Token
  var asLValue: Bool

  func rendered(functionContext: FunctionContext) -> YUL.Expression {
    guard case .self = selfToken.kind else {
      fatalError("Unexpected token \(selfToken.kind)")
    }

    return .inline(functionContext.isInStructFunction ? "_flintSelf" : (asLValue ? "0" : ""))
  }
}
