//
//  IRExpression.swift
//  IRGen
//
//  Created by Franklin Schrans on 27/04/2018.
//

import AST
import Lexer

struct ExpressionFragment {
  let preamble: String
  let expression: String

  init(pre preamble: String, _ expression: String) {
    self.preamble = preamble
    self.expression = expression
  }

  func rendered() -> String {
    return "\(preamble)\n\(expression)"
  }
}

/// Generates code for an expression.
struct IRExpression {
  var expression: Expression
  var asLValue: Bool

  init(expression: Expression, asLValue: Bool = false) {
    self.expression = expression
    self.asLValue = asLValue
  }

  func rendered(functionContext: FunctionContext) -> ExpressionFragment {
    let preamble = ""

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
      return ExpressionFragment(pre: preamble, IRIdentifier(identifier: identifier, asLValue: asLValue)
        .rendered(functionContext: functionContext))
    case .variableDeclaration(let variableDeclaration):
      return ExpressionFragment(pre: preamble, IRVariableDeclaration(variableDeclaration: variableDeclaration)
        .rendered(functionContext: functionContext))
    case .literal(let literal):
      return ExpressionFragment(pre: preamble, IRLiteralToken(literalToken: literal).rendered())
    case .arrayLiteral(let arrayLiteral):
      for e in arrayLiteral.elements {
        guard case .arrayLiteral(_) = e else {
          fatalError("Cannot render non-empty array literals yet")
        }
      }
      return ExpressionFragment(pre: preamble, "0")
    case .dictionaryLiteral(let dictionaryLiteral):
      guard dictionaryLiteral.elements.count == 0 else { fatalError("Cannot render non-empty dictionary literals yet") }
      return ExpressionFragment(pre: preamble, "0")
    case .self(let `self`):
      return IRSelf(selfToken: self, asLValue: asLValue)
        .rendered(functionContext: functionContext)
    case .subscriptExpression(let subscriptExpression):
      return IRSubscriptExpression(subscriptExpression: subscriptExpression,
                                   asLValue: asLValue).rendered(functionContext: functionContext)
    case .sequence(let expressions):
      let (p, c) = expressions.reduce(("", ""), {
        let pre: String = $0.0
        let code: String = $0.1
        let e = IRExpression(expression: $1, asLValue: asLValue).rendered(functionContext: functionContext)
        return (pre + "\n" + e.preamble, code + "\n" + e.expression)
      })
      return ExpressionFragment(pre: p, c)
    case .rawAssembly(let assembly, _):
      return ExpressionFragment(pre: preamble, assembly)
    case .range: fatalError("Range shouldn't be rendered directly")
    }

  }
}
