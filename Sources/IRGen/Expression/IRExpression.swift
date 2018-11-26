//
//  IRExpression.swift
//  IRGen
//
//  Created by Franklin Schrans on 27/04/2018.
//

import AST
import Lexer
import YUL

//struct ExpressionFragment {
//  let preamble: String
//  let expression: String
//
//  init(pre preamble: String, _ expression: String) {
//    self.preamble = preamble
//    self.expression = expression
//  }
//
//  func rendered() -> String {
//    return "\(preamble)\n\(expression)"
//  }
//}

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
      return .inline(IRIdentifier(identifier: identifier, asLValue: asLValue).rendered(functionContext: functionContext).description)
    case .variableDeclaration(let variableDeclaration):
      return .inline(IRVariableDeclaration(variableDeclaration: variableDeclaration)
        .rendered(functionContext: functionContext))
    case .literal(let literal):
      return .inline(IRLiteralToken(literalToken: literal).rendered())
    case .arrayLiteral(let arrayLiteral):
      for e in arrayLiteral.elements {
        guard case .arrayLiteral(_) = e else {
          fatalError("Cannot render non-empty array literals yet")
        }
      }
      return .inline("0")
    case .dictionaryLiteral(let dictionaryLiteral):
      guard dictionaryLiteral.elements.count == 0 else { fatalError("Cannot render non-empty dictionary literals yet") }
      return .inline("0")
    case .self(let `self`):
      return IRSelf(selfToken: self, asLValue: asLValue)
        .rendered(functionContext: functionContext)
    case .subscriptExpression(let subscriptExpression):
      return IRSubscriptExpression(subscriptExpression: subscriptExpression,
                                   asLValue: asLValue).rendered(functionContext: functionContext)
    case .sequence(let expressions):
      let c = expressions.reduce("", {
        let e = IRExpression(expression: $1, asLValue: asLValue).rendered(functionContext: functionContext)
        return $0 + "\n" + e.description
      })
      return .inline(c)
    case .rawAssembly(let assembly, _):
      return .inline(assembly)
    case .range: fatalError("Range shouldn't be rendered directly")
    }

  }
}
