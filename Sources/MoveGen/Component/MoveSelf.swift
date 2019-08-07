//
//  MoveSelf.swift
//  MoveGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import Lexer
import MoveIR
/// Generates code for a "self" expression.
struct MoveSelf {
  var selfToken: Token
  var asLValue: Bool
  public static let selfName = "_flintSelf"

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
    guard case .`self` = selfToken.kind else {
      fatalError("Unexpected token \(selfToken.kind)")
    }
    guard !functionContext.isConstructor else {
      return .identifier("__ERROR_CONSTRUCTOR_SELF_REFERENCE")
    }
    return .identifier(MoveSelf.selfName)
    // return .identifier(functionContext.isInStructFunction ? "_flintSelf" : (asLValue ? "0" : ""))
  }
}
