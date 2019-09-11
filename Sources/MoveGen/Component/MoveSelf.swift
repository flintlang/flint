//
//  MoveSelf.swift
//  MoveGen
//
//

import Foundation
import Lexer
import MoveIR
import Source
import AST
import Diagnostic

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
    guard !functionContext.isConstructor else {
      Diagnostics.add(Diagnostic(severity: .error,
                                 sourceLocation: token.sourceLocation,
                                 message: "`self' reference before all fields initialized in function `init'"))
      Diagnostics.add(Diagnostic(severity: .note,
                                 sourceLocation: token.sourceLocation,
                                 message: #"""
                                          Cannot use `self' in a constructor before all \#
                                          attributes have been assigned to, \#
                                          as some are still unitialised. This includes any \#
                                          method calls which could access instance fields. \#

                                          Instead try moving method calls to after all values \#
                                          have been initialized.
                                          """#))
      Diagnostics.displayAndExit()
    }

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
