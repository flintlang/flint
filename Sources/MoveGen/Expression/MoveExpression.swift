//
//  MoveExpression.swift
//  MoveGen
//
//  Created by Franklin Schrans on 27/04/2018.
//

import AST
import Lexer
import MoveIR

/// Generates code for an expression.
struct MoveExpression {
  var expression: AST.Expression
  var position: Position

  init(expression: AST.Expression, position: Position = .normal) {
    self.expression = expression
    self.position = position
  }

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
    switch expression {
    case .inoutExpression(let inoutExpression):
      return MoveInOutExpression(expression: inoutExpression, position: position)
        .rendered(functionContext: functionContext)
    case .binaryExpression(let binaryExpression):
      return MoveBinaryExpression(binaryExpression: binaryExpression, position: position)
        .rendered(functionContext: functionContext)
    case .typeConversionExpression(let typeConversionExpression):
      return MoveTypeConversionExpression(typeConversionExpression: typeConversionExpression)
        .rendered(functionContext: functionContext)
    case .bracketedExpression(let bracketedExpression):
      return MoveExpression(expression: bracketedExpression.expression, position: position)
        .rendered(functionContext: functionContext)
    case .attemptExpression(let attemptExpression):
      return MoveAttemptExpression(attemptExpression: attemptExpression).rendered(functionContext: functionContext)
    case .functionCall(let functionCall):
      return MoveFunctionCall(functionCall: functionCall).rendered(functionContext: functionContext)
    case .externalCall(let externalCall):
      return MoveExternalCall(externalCall: externalCall).rendered(functionContext: functionContext)
    case .identifier(let identifier):
      return MoveIdentifier(identifier: identifier, position: position).rendered(functionContext: functionContext)
    case .variableDeclaration(let variableDeclaration):
      return MoveVariableDeclaration(variableDeclaration: variableDeclaration)
        .rendered(functionContext: functionContext)
    case .literal(let literal):
      return .literal(MoveLiteralToken(literalToken: literal).rendered())
    case .arrayLiteral(let arrayLiteral):
      for e in arrayLiteral.elements {
        guard case .arrayLiteral(_) = e else {
          fatalError("Cannot render non-empty array literals yet")
        }
      }
      return .literal(Literal.num(0))
    case .dictionaryLiteral(let dictionaryLiteral):
      guard dictionaryLiteral.elements.count == 0 else { fatalError("Cannot render non-empty dictionary literals yet") }
      return .literal(Literal.num(0))
    case .`self`(let expression):
      return MoveSelf(selfToken: expression, position: position)
        .rendered(functionContext: functionContext)
    case .subscriptExpression(let subscriptExpression):
      return MoveSubscriptExpression(subscriptExpression: subscriptExpression,
                                     position: position).rendered(functionContext: functionContext)
    case .sequence(let expressions):
      return .inline(expressions.map({ expression in
        return MoveExpression(expression: expression, position: position)
          .rendered(functionContext: functionContext).description
      }).joined(separator: Move.statementLineSeparator))
    case .rawAssembly(let assembly, _):
      return .inline(assembly)
    case .returnsExpression: fatalError("Returns expression shouldn't be rendered directly")
    case .range: fatalError("Range shouldn't be rendered directly")
    case .emptyExpr: fatalError("EMPTY EXPR")
    }

  }
}
