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
  public static let selfName = "this"

  static func generate(sourceLocation: SourceLocation) -> MoveSelf {
    return MoveSelf(selfToken: Token(kind: Token.Kind.`self`, sourceLocation: sourceLocation), asLValue: false)
  }

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
    guard case .`self` = selfToken.kind else {
      fatalError("Unexpected token \(selfToken.kind)")
    }
    guard !functionContext.isConstructor else {
      print(#"""
            \#u{001B}[1;38;5;196mMoveIR generation error:\#u{001B}[0m \#
            `self' reference before all fields initialized in function `init' in \#(selfToken.sourceLocation)

            \#tCannot use `self' in a constructor before all attributes have been assigned to, \#
            as some are still unitialized. This includes any method calls which could access instance fields.
            \#tInstead try moving method calls to after all values have been initialized.
            """#)
      exit(1)
    }
    return .identifier(MoveSelf.selfName)
    // return .identifier(functionContext.isInStructFunction ? "_flintSelf" : (asLValue ? "0" : ""))
  }
}
