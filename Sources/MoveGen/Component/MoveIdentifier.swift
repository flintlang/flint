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

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
    if identifier.enclosingType != nil && !functionContext.isConstructor {
      return MovePropertyAccess(lhs: .`self`(Token(kind: .`self`, sourceLocation: identifier.sourceLocation)),
                              rhs: .identifier(identifier),
                              asLValue: asLValue)
        .rendered(functionContext: functionContext) // TODO: Preamble not handled
    }
    return .identifier(identifier.name.mangled)
  }

  static func mangleName(_ name: String) -> String {
    return "_\(name)"
  }
}
