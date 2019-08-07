//
//  MoveSelf.swift
//  MoveGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import Foundation
import Lexer
import MoveIR
import Source

/// Generates code for a "self" expression.
struct MoveSelf {
  var selfToken: Token
  var asLValue: Bool

  static func generate(sourceLocation: SourceLocation) -> MoveSelf {
    return MoveSelf(selfToken: Token(kind: Token.Kind.`self`, sourceLocation: sourceLocation), asLValue: false)
  }

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
    guard case .`self` = selfToken.kind else {
      fatalError("Unexpected token \(selfToken.kind)")
    }
    guard !functionContext.isConstructor else {
      return .identifier("__ERROR_CONSTRUCTOR_SELF_REFERENCE")
    }
    return .identifier("this")
    // return .identifier(functionContext.isInStructFunction ? "_flintSelf" : (asLValue ? "0" : ""))
  }
}
