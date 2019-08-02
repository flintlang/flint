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
    guard limitTokenIndex >= currentIndex else {
      fatalError("Limit Token Index should be smaller than the current token's index")
    }

    guard let first = currentToken?.kind else {
      throw raise(.unexpectedEOF())
    }

    // Try to parse an expression passed by inout (e.g., '&a').
    if case .punctuation(.ampersand) = first {
      return .inoutExpression(try parseInoutExpression())
    }

    // Try to parse a returns expression (e.g. returns 1+1)
    if case .returns = first {
      currentIndex += 1
      return .returnsExpression(try parseExpression(upTo: limitTokenIndex))
    }

    if case .call = first {
      return .externalCall(try parseExternalCall(upTo: limitTokenIndex))
    }

    // Try to parse a binary expression.
    // For each Flint binary operator, try to find it in the tokens ahead, and parse the tokens before and after as
    // the LHS and RHS expressions.
    if let expr = try parseBinaryExpression(upTo: limitTokenIndex) {
      return .binaryExpression(expr)
    }

    // Try to parse a type conversion expression.
    if let expr = try parseTypeConversionExpression(upTo: limitTokenIndex) {
      return .typeConversionExpression(expr)
    }

    if case .try = first {
      // Try to parse an attempted function call
      return .attemptExpression(try parseAttemptExpression())
    }

    if case .`self` = first {
      // Try to parse a self expression.
      return .`self`(Token(kind: .`self`, sourceLocation: (try parseSelf()).sourceLocation))
    }

    if case .identifier(_) = first {
      // Try to parse a functon call.
      if case .punctuation(.openBracket) = tokens[currentIndex + 1].kind {
        return .functionCall(try parseFunctionCall())
      }

      // Try to parse a subscript expression.
      if indexOfFirstAtCurrentDepth([.punctuation(.openSquareBracket)], maxIndex: limitTokenIndex) != nil {
        return .subscriptExpression(try parseSubscriptExpression())
      }

      // If none of the previous expressions could be constructed, the expression is an identifier.
      return .identifier(try parseIdentifier())
    }
    if case .punctuation(.openBracket) = first {
      // Check for a range by descending into the open bracket and looking for a range operator
      currentIndex += 1
      let isRange = indexOfFirstAtCurrentDepth([.punctuation(.halfOpenRange),
                                                .punctuation(.closedRange)], maxIndex: limitTokenIndex) != nil
      currentIndex -= 1

      if isRange {
        return .range(try parseRangeExpression())
      }

      // Try to parse a bracketed expression.
      return .bracketedExpression(try parseBracketedExpression())

    }
    if case .punctuation(.openSquareBracket) = first {

      // Check for a dictionary by descending into the open bracket and looking for a colon
      currentIndex += 1
      let isDict = indexOfFirstAtCurrentDepth([.punctuation(.colon)], maxIndex: limitTokenIndex) != nil
      currentIndex -= 1
      if isDict {
        return .dictionaryLiteral(try parseDictionaryLiteral())
      }

      // Try to parse an array literal.
      return .arrayLiteral(try parseArrayLiteral())
    }
    if case .literal(_) = first {
      // Try to parse a literal.
      return .literal(try parseLiteral())
    }

    switch first {
    case .public, .visible, .var, .let:
      // Try to parse a variable declaration.
      let modifiers = try parseModifiers()
      return .variableDeclaration(try parseVariableDeclaration(modifiers: modifiers, upTo: limitTokenIndex))
    default:
      // Invalid expression
      try syncNewLine(diagnostic: .expectedExpr(at: latestSource))
      return .emptyExpr(latestSource)
    }
  }

  // MARK: Binary
  func parseBinaryExpression(upTo limitTokenIndex: Int) throws -> BinaryExpression? {
    for op in Token.Kind.Punctuation.allBinaryOperatorsByIncreasingPrecedence {
      guard let index = indexOfFirstAtCurrentDepth([.punctuation(op)], maxIndex: limitTokenIndex) else { continue }
      let lhs = try parseExpression(upTo: index)
      let operatorToken = try consume(.punctuation(op), or: .expectedValidOperator(at: latestSource))
      let rhs = try parseExpression(upTo: limitTokenIndex)
      return BinaryExpression(lhs: lhs, op: operatorToken, rhs: rhs)
    }
    return nil
  }

  // MARK: Casting
  func parseTypeConversionExpression(upTo limitTokenIndex: Int) throws -> TypeConversionExpression? {
    guard let index = indexOfFirstAtCurrentDepth([.as], maxIndex: limitTokenIndex) else {
      return nil
    }

    let expression = try parseExpression(upTo: index)
    let asToken = try consume(.as, or: .dummy())
    var kind: TypeConversionExpression.Kind = .coerce
    if let currentToken = currentToken {
      if currentToken.kind == .punctuation(.bang) {
        kind = .cast
        try consume(.punctuation(.bang), or: .dummy())
      } else if currentToken.kind == .punctuation(.question) {
        kind = .castOptional
        try consume(.punctuation(.question), or: .dummy())
      }
    }
    let type = try parseType()

    return TypeConversionExpression(expression: expression, asToken: asToken, kind: kind, type: type)
  }

  // MARK: Bracketed
  func parseBracketedExpression() throws -> BracketedExpression {
    let openBracketToken = try consume(.punctuation(.openBracket), consumingTrailingNewlines: false,
                                       or: .expectedExpr(at: latestSource))

    if let closeBracketIndex = indexOfFirstAtCurrentDepth([.punctuation(.closeBracket)]) {
      let expression = try parseExpression(upTo: closeBracketIndex)
      let closeBracketToken = try consume(.punctuation(.closeBracket), or: .dummy())
      consumeNewLines()

      return BracketedExpression(expression: expression,
                                 openBracketToken: openBracketToken,
                                 closeBracketToken: closeBracketToken)
    } else {
      try syncNewLine(diagnostic: .expectedCloseParen(at: latestSource))

      return BracketedExpression(
          expression: .emptyExpr(latestSource),
          openBracketToken: Token(kind: .punctuation(.openBracket), sourceLocation: latestSource),
          closeBracketToken: Token(kind: .punctuation(.closeBracket), sourceLocation: latestSource))
    }
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
    guard let statementEndIndex = indexOfFirstAtCurrentDepth(
        [
          .punctuation(.comma),
          .punctuation(.closeBracket)
        ],
        maxIndex: tokens.count) else {
      throw raise(.expectedEndAfterInout(at: latestSource))
    }
    let expression = try parseExpression(upTo: statementEndIndex)
    return InoutExpression(ampersandToken: ampersandToken, expression: expression)
  }

  // MARK: External Calls
  func parseExternalCall(upTo limitTokenIndex: Int) throws -> ExternalCall {
    try consume(.call, or: .badDeclaration(at: latestSource))

    var arguments: [FunctionArgument] = []
    if tokens[currentIndex].kind == .punctuation(.openBracket) {
      (arguments, _) = try parseFunctionCallArgumentList()
    }

    var mode: ExternalCall.Mode = .normal
    if tokens[currentIndex].kind == .punctuation(.question) ||
       tokens[currentIndex].kind == .punctuation(.bang) {
      let token = try consume(anyOf: [.punctuation(.question), .punctuation(.bang)], or: .dummy())

      if token.kind == .punctuation(.bang) {
        mode = .isForced
      } else if token.kind == .punctuation(.question) {
        mode = .returnsGracefullyOptional
      }
    }

    guard let functionCall = try parseBinaryExpression(upTo: limitTokenIndex) else {
      throw raise(.badDeclaration(at: tokens[currentIndex].sourceLocation))
    }

    return ExternalCall(hyperParameters: arguments,
                        functionCall: functionCall,
                        mode: mode)
  }

  // MARK: Function Call
  func parseFunctionCall() throws -> FunctionCall {
    let identifier = try parseIdentifier()
    let (arguments, closeBracketToken) = try parseFunctionCallArgumentList()

    return FunctionCall(identifier: identifier,
                        arguments: arguments,
                        closeBracketToken: closeBracketToken,
                        isAttempted: false)
  }

  func parseFunctionCallArgumentList() throws -> ([FunctionArgument], closeBracketToken: Token) {
    var arguments = [FunctionArgument]()

    try consume(.punctuation(.openBracket), or: .expectedParameterOpenParenthesis(at: latestSource))

    var closeBracketToken: Token

    guard let closingIndex = indexOfFirstAtCurrentDepth([.punctuation(.closeBracket)]) else {
      throw raise(.expectedCloseParen(at: latestSource))
    }

    while currentIndex < closingIndex {
      guard let argumentEnd = indexOfFirstAtCurrentDepth([.punctuation(.comma), .punctuation(.closeBracket)]) else {
        throw raise(.expectedSeparator(at: latestSource))
      }
      arguments.append(try parseFunctionCallArgument(upTo: argumentEnd))
      if currentIndex < closingIndex {
        try consume(.punctuation(.comma), or: .expectedSeparator(at: latestSource))
      }
    }
    closeBracketToken = try consume(.punctuation(.closeBracket),
                                    or: .expectedParameterCloseParenthesis(at: latestSource))

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
    let op = try consume(anyOf: [.punctuation(.halfOpenRange),
                                 .punctuation(.closedRange)], or: .expectedRangeOperator(at: latestSource))
    let end = try parseLiteral()
    let endToken = try consume(.punctuation(.closeBracket), or: .expectedCloseParen(at: latestSource))

    return AST.RangeExpression(startToken: startToken,
                               endToken: endToken,
                               initial: .literal(start),
                               bound: .literal(end),
                               op: op)
  }

  // MARK: Dictionary Literal
  func parseDictionaryLiteral() throws -> AST.DictionaryLiteral {
    let openSquareBracket = try consume(.punctuation(.openSquareBracket), or: .expectedExpr(at: latestSource))

    var elements = [AST.DictionaryLiteral.Entry]()

    var closeSquareBracket: Token

    if currentToken?.kind == .punctuation(.colon) {
      /// The dictionary literal doesn't contain any elements.
      _ = try consume(.punctuation(.colon), or: .dummy())
      closeSquareBracket = try consume(.punctuation(.closeSquareBracket),
                                       or: .expectedCloseSquareDictionaryLiteral(at: latestSource))
      return AST.DictionaryLiteral(openSquareBracketToken: openSquareBracket,
                                   elements: elements,
                                   closeSquareBracketToken: closeSquareBracket)
    }

    guard let closingIndex = indexOfFirstAtCurrentDepth([.punctuation(.closeSquareBracket)]) else {
      throw raise(.expectedCloseParen(at: latestSource))
    }

    while currentIndex < closingIndex {
      guard let elementEnd = indexOfFirstAtCurrentDepth([.punctuation(.comma),
                                                         .punctuation(.closeSquareBracket)]) else {
        throw raise(.expectedSeparator(at: latestSource))
      }
      let element = try parseDictionaryElement(upTo: elementEnd)
      elements.append(.init(key: element.0, value: element.1))
      if currentIndex < closingIndex {
        try consume(.punctuation(.comma), or: .expectedSeparator(at: latestSource))
      }
    }
    closeSquareBracket = try consume(.punctuation(.closeBracket),
                                     or: .expectedParameterCloseParenthesis(at: latestSource))

    return AST.DictionaryLiteral(openSquareBracketToken: openSquareBracket,
                                 elements: elements,
                                 closeSquareBracketToken: closeSquareBracket)
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
    var base: Expression

    let identifier = try parseIdentifier()
    base = .identifier(identifier)

    while true {
      try consume(.punctuation(.openSquareBracket), or: .expectedExpr(at: latestSource))
      guard let index = indexOfFirstAtCurrentDepth([.punctuation(.closeSquareBracket)]) else {
        throw raise(.expectedCloseSquareSubscript(at: latestSource))
      }
      let indexExpression = try parseExpression(upTo: index)
      let closeSquareBracketToken = try consume(.punctuation(.closeSquareBracket),
                                                or: .expectedCloseSquareSubscript(at: latestSource))
      base = .subscriptExpression(SubscriptExpression(baseExpression: base,
                                                      indexExpression: indexExpression,
                                                      closeSquareBracketToken: closeSquareBracketToken))
      if currentToken?.kind != .punctuation(.openSquareBracket),
         case .subscriptExpression(let expr) = base {
        return expr
      }
    }
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
