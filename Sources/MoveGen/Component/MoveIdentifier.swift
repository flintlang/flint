//
//  MoveIdentifier.swift
//  MoveGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST
import Lexer
import MoveIR

/// Generates code for an identifier.
struct MoveIdentifier {
  var identifier: AST.Identifier
  var position: Position

  init(identifier: AST.Identifier, position: Position = .normal) {
    self.identifier = identifier
    self.position = position
  }

  func rendered(functionContext: FunctionContext, forceMove: Bool = false) -> MoveIR.Expression {
    if identifier.enclosingType != nil {
      if functionContext.isConstructor {
        return .identifier(MoveSelf.selfPrefix + identifier.name)
      } else {
        return MovePropertyAccess(
            lhs: .`self`(Token(kind: .`self`, sourceLocation: identifier.sourceLocation)),
            rhs: .identifier(identifier),
            position: position
        ).rendered(functionContext: functionContext) // TODO: Preamble not handled
      }
    }
    if identifier.isSelf {
      return MoveSelf(selfToken: identifier.identifierToken, position: position)
          .rendered(functionContext: functionContext, forceMove: forceMove)
    }

    let irIdentifier = MoveIR.Expression.identifier(identifier.name.mangled)

    if case .left = position {
      return irIdentifier
    } else {
      let rawType: RawType? = functionContext.scopeContext.type(for: identifier.name)
      if forceMove {
        return MoveIR.Expression.transfer(.move(irIdentifier))
      } else {
        return MoveIR.Expression.transfer(.copy(irIdentifier))
      }
    }
  }
}
