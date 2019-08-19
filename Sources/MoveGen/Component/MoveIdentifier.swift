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
        return .identifier(MoveSelf.prefix + identifier.name)
      } else {
        return MovePropertyAccess(
            lhs: .`self`(Token(kind: .`self`, sourceLocation: identifier.sourceLocation)),
            rhs: .identifier(identifier),
            position: position
        ).rendered(functionContext: functionContext) // TODO: Preamble not handled
      }
    }
    if identifier.isSelf {
      return MoveSelf(token: identifier.identifierToken, position: position)
          .rendered(functionContext: functionContext, forceMove: forceMove)
    }

    let irIdentifier = MoveIR.Expression.identifier(identifier.name.mangled)

    if forceMove {
      return .transfer(.move(irIdentifier))
    } else if let type = functionContext.scopeContext.type(for: identifier.name),
              !type.isInout && type.isUserDefinedType {
      return .operation(.mutableReference(irIdentifier))
    } else if position == .left {
      return irIdentifier
    } else if position == .accessed {
      return .operation(.dereference(.operation(.mutableReference(
          .transfer(.copy(irIdentifier))
      ))))
    } else {
      return .transfer(.copy(irIdentifier))
    }
  }
}
