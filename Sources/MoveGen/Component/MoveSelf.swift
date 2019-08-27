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
  var token: Token
  var position: Position = .normal

  public static let name = "this"
  public static let prefix = "__\(name)_"

  public var identifier: AST.Identifier {
    return AST.Identifier(identifierToken: token)
  }

  static func generate(sourceLocation: SourceLocation, position: Position = .normal) -> MoveSelf {
    return MoveSelf(token: Token(kind: Token.Kind.`self`, sourceLocation: sourceLocation), position: position)
  }

  func rendered(functionContext: FunctionContext, forceMove: Bool = false) -> MoveIR.Expression {
    guard case .`self` = token.kind else {
      fatalError("Unexpected token \(token.kind)")
    }
    //guard !functionContext.isConstructor else {
    //  print(#"""
    //        \#u{001B}[1;38;5;196mMoveIR generation error:\#u{001B}[0m \#
    //        `self' reference before all fields initialized in function `init' in \#(token.sourceLocation)
    //        \#tCannot use `self' in a constructor before all attributes have been assigned to, \#
    //        as some are still unitialized. This includes any method calls which could access instance fields.
    //        \#tInstead try moving method calls to after all values have been initialized.
    //        """#)
    //  exit(1)
    //}

    if position == .left {
      return .identifier(MoveSelf.name)
    } else if forceMove {
      return .transfer(.move(.identifier(MoveSelf.name)))
    } else if !(functionContext.selfType.isInout) {
      return .identifier(MoveSelf.name)
    } else if position == .accessed {
      return .operation(.dereference(.operation(.mutableReference(
          .transfer(.copy(.identifier(MoveSelf.name)))
      ))))
    } else {
      return .transfer(.copy(.identifier(MoveSelf.name)))
    }
  }
}
