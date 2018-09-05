//
//  Parser+Expressions.swift
//  Parser
//
//  Created by Hails, Daniel R on 03/09/2018.
//

import AST
import Lexer

extension Parser {
  /// Parse an expression which ends one token before the one at `limitTokenIndex`.
  /// For instance in the expression `a + 2)`, and `limitTokenIndex` refers to the token `)`, the function will return
  /// the expression `a + 2`.
  ///
  /// - Parameter limitTokenIndex: The index of the token to parse up to.
  /// - Throws: If an expression couldn't be parsed.
  func parseExpression(upTo limitTokenIndex: Int) throws -> Expression {
    var binaryExpression: BinaryExpression? = nil

    guard limitTokenIndex >= currentIndex else {
      fatalError("Limit Token Index should be smaller than the current token's index")
    }

    // Try to parse the expression as the different types of Flint expressions.

    // Try to parse an expression passed by inout (e.g., '&a').
    if let inoutExpression = attempt(parseInoutExpression) {
      return .inoutExpression(inoutExpression)
    }

    // Try to parse a binary expression.
    // For each Flint binary operator, try to find it in the tokens ahead, and parse the tokens before and after as
    // the LHS and RHS expressions.
    for op in Token.Kind.Punctuation.allBinaryOperatorsByIncreasingPrecedence {
      guard let index = indexOfFirstAtCurrentDepth([.punctuation(op)], maxIndex: limitTokenIndex) else { continue }
      let lhs = attempt(try parseExpression(upTo: index))
      let operatorToken = attempt(try consume(.punctuation(op), or: .expectedValidOperator(at: latestSource)))
      let rhs = attempt(try parseExpression(upTo: limitTokenIndex))

      if let lhs = lhs, let opToken = operatorToken, let rhs = rhs {
        binaryExpression = BinaryExpression(lhs: lhs, op: opToken, rhs: rhs)
        break
      }
    }

    // Return the binary expression if a valid one could be constructed.
    if let binExp = binaryExpression {
      return .binaryExpression(binExp)
    }

    // Try to parse an attempted function call
    if let attemptExpression = attempt(try parseAttemptExpression()){
      return .attemptExpression(attemptExpression)
    }

    // Try to parse a function call.
    if let functionCall = attempt(try parseFunctionCall()) {
      return .functionCall(functionCall)
    }

    // Try to parse an range.
    if let rangeExpression = attempt(parseRangeExpression) {
      return .range(rangeExpression)
    }

    // Try to parse an array literal.
    if let arrayLiteral = attempt(parseArrayLiteral) {
      return .arrayLiteral(arrayLiteral)
    }

    // Try to parse a dictionary literal.
    if let dictionaryLiteral = attempt(parseDictionaryLiteral) {
      return .dictionaryLiteral(dictionaryLiteral)
    }

    // Try to parse a literal.
    if let literal = attempt(parseLiteral) {
      return .literal(literal)
    }

    // Try to parse a variable declaration.
    if let variableDeclaration = attempt(try parseVariableDeclaration()) {
      return .variableDeclaration(variableDeclaration)
    }

    // Try to parse a bracketed expression.
    if let bracketedExpression = attempt(try parseBracketedExpression()) {
      return .bracketedExpression(bracketedExpression)
    }

    // Try to parse a self expression.
    if let `self` = attempt(parseSelf) {
      return .self(Token(kind: .self, sourceLocation: self.sourceLocation))
    }

    // Try to parse a subscript expression.
    if let subscriptExpression = attempt(try parseSubscriptExpression()) {
      return .subscriptExpression(subscriptExpression)
    }

    // If none of the previous expressions could be constructed, the expression is an identifier.
    if let identifier = attempt(try parseIdentifier()) {
      return .identifier(identifier)
    }

    // Emit error
    throw raise(.expectedExpr(at: latestSource))
  }

  // MARK: Bracked
  func parseBracketedExpression() throws -> BracketedExpression {
    let openBracketToken = try consume(.punctuation(.openBracket), or: .expectedExpr(at: latestSource))
    guard let closeBracketIndex = indexOfFirstAtCurrentDepth([.punctuation(.closeBracket)]) else {
      throw raise(.expectedCloseParen(at: latestSource))
    }
    let expression = try parseExpression(upTo: closeBracketIndex)
    let closeBracketToken = try! consume(.punctuation(.closeBracket), or: .dummy())

    return BracketedExpression(expression: expression, openBracketToken: openBracketToken, closeBracketToken: closeBracketToken)
  }

  // MARK: Attempt
  func parseAttemptExpression() throws -> AttemptExpression {
    let tryToken = try consume(.try, or: .expectedExpr(at: latestSource))
    let sort = try consume(anyOf: [.punctuation(.bang), .punctuation(.question)], or: .expectedSort(at: latestSource))
    var functionCall = try parseFunctionCall()
    functionCall.isAttempted = true
    return AttemptExpression(token: tryToken, sort: sort, functionCall: functionCall)
  }

  // MARK: Inout
  func parseInoutExpression() throws -> InoutExpression {
    let ampersandToken = try consume(.punctuation(.ampersand), or: .expectedExpr(at: latestSource))
    guard let statementEndIndex = indexOfFirstAtCurrentDepth([.punctuation(.comma), .punctuation(.closeBracket)], maxIndex: tokens.count) else {
      throw raise(.expectedEndAfterInout(at: latestSource))
    }
    guard let identifier = attempt(try parseExpression(upTo: statementEndIndex)) else {
      throw raise(.expectedIdentifierForInOutExpr(at: latestSource))
    }
    return InoutExpression(ampersandToken: ampersandToken, expression: identifier)
  }

  // MARK: Function Call
  func parseFunctionCall() throws -> FunctionCall {
    let identifier = try parseIdentifier()
    let (arguments, closeBracketToken) = try parseFunctionCallArgumentList()

    return FunctionCall(identifier: identifier, arguments: arguments, closeBracketToken: closeBracketToken, isAttempted: false)
  }

  func parseFunctionCallArgumentList() throws -> ([FunctionArgument], closeBracketToken: Token) {
    var arguments = [FunctionArgument]()

    try consume(.punctuation(.openBracket), or: .expectedParameterOpenParenthesis(at: latestSource))

    var closeBracketToken: Token!

    while let argumentEnd = indexOfFirstAtCurrentDepth([.punctuation(.comma), .punctuation(.closeBracket)]) {
      if let argument = attempt(try parseFunctionCallArgument(upTo: argumentEnd)) {
        let token = try consume(tokens[argumentEnd].kind, or: .expectedParameterType(at: latestSource))
        arguments.append(argument)
        if token.kind == .punctuation(.closeBracket) {
          closeBracketToken = token
          break
        }
      } else {
        break
      }
    }

    if arguments.isEmpty {
      closeBracketToken = try consume(.punctuation(.closeBracket), or: .expectedParameterCloseParenthesis(at: latestSource))
    }

    return (arguments, closeBracketToken)
  }

  func parseFunctionCallArgument(upTo: Int) throws -> FunctionArgument {
    // Find next colon
    if let firstPartEnd = indexOfFirstAtCurrentDepth([.punctuation(.colon)]),
      firstPartEnd < upTo {
      let identifier = try parseIdentifier()
      try consume(.punctuation(.colon), or: .expectedColonAfterArgumentLabel(at: latestSource))
      let expression = try parseExpression(upTo: upTo)
      return FunctionArgument(identifier: identifier, expression: expression)
    }
    let expression = try parseExpression(upTo: upTo)
    return FunctionArgument(identifier: nil, expression: expression)
  }

  // MARK: Range
  func parseRangeExpression() throws -> AST.RangeExpression {
    let startToken = try consume(.punctuation(.openBracket), or: .expectedExpr(at: latestSource))
    let start = try parseLiteral()
    let op = try consume(anyOf: [.punctuation(.halfOpenRange), .punctuation(.closedRange)], or: .expectedRangeOperator(at: latestSource))
    let end = try parseLiteral()
    let endToken = try consume(.punctuation(.closeBracket), or: .expectedCloseParen(at: latestSource))

    return AST.RangeExpression(startToken: startToken, endToken: endToken, initial: .literal(start), bound: .literal(end), op: op)
  }

  // MARK: Dictionary Literal
  func parseDictionaryLiteral() throws -> AST.DictionaryLiteral {
    let openSquareBracket = try consume(.punctuation(.openSquareBracket), or: .expectedExpr(at: latestSource))

    var elements = [AST.DictionaryLiteral.Entry]()

    var closeSquareBracket: Token?

    if let _ = attempt(try consume(.punctuation(.colon), or: .expectedColonDictionaryLiteral(at: latestSource))) {
      /// The dictionary literal doesn't contain any elements.

      closeSquareBracket = try consume(.punctuation(.closeSquareBracket), or: .expectedCloseSquareDictionaryLiteral(at: latestSource))
      return AST.DictionaryLiteral(openSquareBracketToken: openSquareBracket, elements: elements, closeSquareBracketToken: closeSquareBracket!)
    }

    while let elementEnd = indexOfFirstAtCurrentDepth([.punctuation(.comma), .punctuation(.closeSquareBracket)]) {
      if let element = attempt(try parseDictionaryElement(upTo: elementEnd)) {
        let token = try consume(tokens[elementEnd].kind, or: .expectedSeparator(at: latestSource))
        if token.kind == .punctuation(.closeSquareBracket) { closeSquareBracket = token }
        elements.append(.init(key: element.0, value: element.1))
      } else {
        break
      }
    }

    if elements.isEmpty {
      closeSquareBracket = try consume(.punctuation(.closeSquareBracket), or: .expectedCloseSquareDictionaryLiteral(at: latestSource))
    }

    return AST.DictionaryLiteral(openSquareBracketToken: openSquareBracket, elements: elements, closeSquareBracketToken: closeSquareBracket!)
  }

  func parseDictionaryElement(upTo commaIndex: Int) throws -> (Expression, Expression) {
    guard let colonIndex = indexOfFirstAtCurrentDepth([.punctuation(.comma)], maxIndex: commaIndex) else {
      throw raise(.expectedSeparator(at: latestSource))
    }

    let key = try parseExpression(upTo: colonIndex)
    try consume(.punctuation(.colon), or: .expectedColonDictionaryLiteral(at: latestSource))
    let value = try parseExpression(upTo: commaIndex)

    return (key, value)
  }

  // MARK: Subscript
  func parseSubscriptExpression() throws -> SubscriptExpression {
    var base: SubscriptExpression

    guard let identifier = attempt(try parseIdentifier()) else {
      throw raise(.expectedExpr(at: latestSource))
    }
    try consume(.punctuation(.openSquareBracket), or: .expectedExpr(at: latestSource))
    guard let index = indexOfFirstAtCurrentDepth([.punctuation(.closeSquareBracket)]) else {
      throw raise(.expectedCloseSquareSubscript(at: latestSource))
    }
    let indexExpression = try parseExpression(upTo: index)
    let closeSquareBracketToken = try consume(.punctuation(.closeSquareBracket), or: .expectedCloseSquareSubscript(at: latestSource))
    base = SubscriptExpression(baseExpression: .identifier(identifier), indexExpression: indexExpression, closeSquareBracketToken: closeSquareBracketToken)
    while let _ = attempt(try consume(.punctuation(.openSquareBracket), or: .expectedCloseSquareSubscript(at: latestSource))) {
      guard let index = indexOfFirstAtCurrentDepth([.punctuation(.closeSquareBracket)]) else {
        throw raise(.expectedCloseSquareSubscript(at: latestSource))
      }
      let indexExpression = try parseExpression(upTo: index)
      let closeSquareBracketToken = try consume(.punctuation(.closeSquareBracket), or: .expectedCloseSquareSubscript(at: latestSource))
      base = SubscriptExpression(baseExpression: .subscriptExpression(base), indexExpression: indexExpression, closeSquareBracketToken: closeSquareBracketToken)
    }

    return base
  }

  // MARK: Self
  func parseSelf() throws -> Token {
    guard let token = currentToken, case .self = token.kind else {
      throw raise(.expectedExpr(at: latestSource))
    }
    currentIndex += 1
    consumeNewLines()
    return token
  }

}

