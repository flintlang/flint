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
import AST

/// Generates code for a "self" expression.
struct MoveSelf {
  var selfToken: Token
  var position: Position = .normal

  public static let selfName = "this"
  public static let selfPrefix = "__\(selfName)_"

  static func generate(sourceLocation: SourceLocation, position: Position = .normal) -> MoveSelf {
    return MoveSelf(selfToken: Token(kind: Token.Kind.`self`, sourceLocation: sourceLocation), position: position)
  }

  func rendered(functionContext: FunctionContext, forceMove: Bool = false) -> MoveIR.Expression {
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

    if case .left = position {
      return .identifier(MoveSelf.selfName)
    } else if forceMove {
      return .transfer(.move(.identifier(MoveSelf.selfName)))
    } else if position == .accessed {
      return .operation(.dereference(.operation(.mutableReference(
          .transfer(.copy(.identifier(MoveSelf.selfName)))
      ))))
    } else {
      return .transfer(.copy(.identifier(MoveSelf.selfName)))
    }
  }
}
