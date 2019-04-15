//
//  IRExpression.swift
//  IRGen
//
//  Created by Franklin Schrans on 27/04/2018.
//

import AST
import Lexer
import YUL

/// Generates code for an expression.
struct IRExpression {
  var expression: AST.Expression
  var asLValue: Bool

  init(expression: AST.Expression, asLValue: Bool = false) {
    self.expression = expression
    self.asLValue = asLValue
  }

  func rendered(functionContext: FunctionContext) -> YUL.Expression {
    switch expression {
    case .inoutExpression(let inoutExpression):
      return IRExpression(expression: inoutExpression.expression, asLValue: true)
        .rendered(functionContext: functionContext)
    case .binaryExpression(let binaryExpression):
      return IRBinaryExpression(binaryExpression: binaryExpression, asLValue: asLValue)
        .rendered(functionContext: functionContext)
    case .typeConversionExpression(let typeConversionExpression):
      return IRTypeConversionExpression(typeConversionExpression: typeConversionExpression)
        .rendered(functionContext: functionContext)
    case .bracketedExpression(let bracketedExpression):
      return IRExpression(expression: bracketedExpression.expression, asLValue: asLValue)
        .rendered(functionContext: functionContext)
    case .attemptExpression(let attemptExpression):
      return IRAttemptExpression(attemptExpression: attemptExpression).rendered(functionContext: functionContext)
    case .functionCall(let functionCall):
      return IRFunctionCall(functionCall: functionCall).rendered(functionContext: functionContext)
    case .externalCall(let externalCall):
      return IRExternalCall(externalCall: externalCall).rendered(functionContext: functionContext)
    case .identifier(let identifier):
      return IRIdentifier(identifier: identifier, asLValue: asLValue).rendered(functionContext: functionContext)
    case .variableDeclaration(let variableDeclaration):
      return IRVariableDeclaration(variableDeclaration: variableDeclaration)
        .rendered(functionContext: functionContext)
    case .literal(let literal):
      return .literal(IRLiteralToken(literalToken: literal).rendered())
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
    case .self(let `self`):
      return IRSelf(selfToken: self, asLValue: asLValue)
        .rendered(functionContext: functionContext)
    case .subscriptExpression(let subscriptExpression):
      return IRSubscriptExpression(subscriptExpression: subscriptExpression,
                                   asLValue: asLValue).rendered(functionContext: functionContext)
    case .sequence(let expressions):
      return .inline(expressions.map({ expression in
        return IRExpression(expression: expression, asLValue: asLValue)
          .rendered(functionContext: functionContext).description
      }).joined(separator: "\n"))
    case .rawAssembly(let assembly, _):
      return .inline(assembly)
    case .returnsExpression: fatalError("Returns expression shouldn't be rendered directly")
    case .range: fatalError("Range shouldn't be rendered directly")
    }

  }
}
