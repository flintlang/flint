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
  var asLValue: Bool

  init(identifier: AST.Identifier, asLValue: Bool = false) {
    self.identifier = identifier
    self.asLValue = asLValue
  }

  func rendered(functionContext: FunctionContext, forceMove: Bool = false) -> MoveIR.Expression {
    if identifier.enclosingType != nil {
      if functionContext.isConstructor {
        return .identifier(MoveSelf.selfPrefix + identifier.name)
      } else {
        return MovePropertyAccess(
            lhs: .`self`(Token(kind: .`self`, sourceLocation: identifier.sourceLocation)),
            rhs: .identifier(identifier),
            asLValue: asLValue
        ).rendered(functionContext: functionContext) // TODO: Preamble not handled
      }
    }
    if identifier.isSelf {
      return MoveSelf(selfToken: identifier.identifierToken, asLValue: asLValue)
          .rendered(functionContext: functionContext, forceMove: forceMove)
    }

    let irIdentifier = MoveIR.Expression.identifier(identifier.name.mangled)

    if asLValue {
      return irIdentifier
    } else {
      let rawType: RawType? = functionContext.scopeContext.type(for: identifier.name)
      if (rawType?.isCurrencyType ?? false)
         || functionContext.environment.isContractDeclared(rawType?.name ?? "")
         || forceMove {
        return MoveIR.Expression.transfer(.move(irIdentifier))
      } else {
        return MoveIR.Expression.transfer(.copy(irIdentifier))
      }
    }
  }
}
