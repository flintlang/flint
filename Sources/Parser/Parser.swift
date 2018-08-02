//
//  Compiler.swift
//  flintcPackageDescription
//
//  Created by Franklin Schrans on 12/19/17.
//

import Foundation
import AST

/// The parser, which creates an Abstract Syntax Tree (AST) from a list of tokens.
public class Parser {
  /// The list of tokens from which to create an AST.
  var tokens: [Token]

  /// The index of the current token being processed.
  var currentIndex: Int

  /// The current token being processed.
  var currentToken: Token? {
    return currentIndex < tokens.count ? tokens[currentIndex] : nil
  }

  /// Semantic information about the source program.
  var environment = Environment()

  public init(tokens: [Token]) {
    self.tokens = tokens
    self.currentIndex = tokens.startIndex
  }

  /// Parses the token list.
  ///
  /// - Returns:  A triple containing the top-level Flint module (the root of the AST), the generated environment,
  ///             and the list of diagnostics emitted.
  public func parse() -> (TopLevelModule?, Environment, [Diagnostic]) {
    do {
      return (try parseTopLevelModule(), environment, [])
    } catch ParserError.expectedToken(let tokenKind, sourceLocation: let sourceLocation) {
      // A unhandled parsing error was thrown when parsing the program.
      return (nil, environment, [Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected token '\(tokenKind)'")])
    } catch {
      // An invalid error was thrown.
      fatalError()
    }
  }

  /// Consumes the given token from the given list, i.e. discard it and move on to the next one. Throws if the current
  /// token being processed isn't equal to the given token.
  ///
  /// - Parameters:
  ///   - token: The token to consume.
  ///   - consumingTrailingNewlines: Whether newline tokens should be consumed after consuming the given token.
  /// - Returns: The token which was consumed.
  /// - Throws: A `ParserError.expectedToken` if the current token being processed isn't equal to the given token.
  @discardableResult
  func consume(_ token: Token.Kind, consumingTrailingNewlines: Bool = true) throws -> Token {
    guard let first = currentToken, first.kind == token else {
      throw ParserError.expectedToken(token, sourceLocation: currentToken?.sourceLocation)
    }

    currentIndex += 1

    if consumingTrailingNewlines {
      consumeNewLines()
    }

    return first
  }

  /// Consumes one of the given tokens from the given list, i.e. discard it and move on to the next one. Throws if the current
  /// token being processed isn't equal to any of the given tokens.
  ///
  /// - Parameters:
  ///   - tokens: The tokens that can be consumed.
  ///   - consumingTrailingNewlines: Whether newline tokens should be consumed after consuming the given token.
  /// - Returns: The token which was consumed.
  /// - Throws: A `ParserError.expectedTokens` if the current token being processed isn't equal to the given token.
  @discardableResult
  func consume(anyOf: [Token.Kind], consumingTrailingNewlines: Bool = true) throws -> Token {
    guard let first = currentToken, anyOf.contains(first.kind) else {
      throw ParserError.expectedTokens(anyOf, sourceLocation: currentToken?.sourceLocation)
    }

    currentIndex += 1

    if consumingTrailingNewlines {
      consumeNewLines()
    }

    return first
  }

  /// Consume newlines tokens up to the first non-newline token.
  func consumeNewLines() {
    while currentIndex < tokens.count, tokens[currentIndex].kind == .newline {
      currentIndex += 1
    }
  }

  /// Wraps the given throwable task, wrapping its return value in an optional. If the task throws, the function returns
  /// `nil`.
  ///
  /// - Parameter task: The task to execute.
  /// - Returns: The return value of the task, or `nil` if the task threw.
  func attempt<ReturnType>(task: () throws -> ReturnType) -> ReturnType? {
    let nextIndex = self.currentIndex
    do {
      return try task()
    } catch {
      self.currentIndex = nextIndex
      return nil
    }
  }

  /// Wraps the given throwable task, wrapping its return value in an optional. If the task throws, the function returns
  /// `nil`.
  ///
  /// **Note:** This function is the same as attempt(task:), but where task is an @autoclosure. Functions cannot be
  /// passed as @autoclosure arguments.
  ///
  /// - Parameter task: The task to execute.
  /// - Returns: The return value of the task, or `nil` if the task threw.
  func attempt<ReturnType>(_ task: @autoclosure () throws -> ReturnType) -> ReturnType? {
    let nextIndex = self.currentIndex
    do {
      return try task()
    } catch {
      self.currentIndex = nextIndex
      return nil
    }
  }
}

extension Parser {
  func parseTopLevelModule() throws -> TopLevelModule {
    consumeNewLines()
    let topLevelDeclarations = try parseTopLevelDeclarations()
    return TopLevelModule(declarations: topLevelDeclarations)
  }

  func parseTopLevelDeclarations() throws -> [TopLevelDeclaration] {
    var declarations = [TopLevelDeclaration]()

    while true {
      guard let first = currentToken else { break }

      // At the top-level, a contract, a struct, or a contract behavior can be declared.
      switch first.kind {
      case .contract:
        let contractDeclaration = try parseContractDeclaration()
        environment.addContract(contractDeclaration)
        if contractDeclaration.isStateful {
          environment.addEnum(contractDeclaration.stateEnum)
        }
        declarations.append(.contractDeclaration(contractDeclaration))
      case .struct:
        let structDeclaration = try parseStructDeclaration()
        environment.addStruct(structDeclaration)
        declarations.append(.structDeclaration(structDeclaration))
      case .enum:
        let enumDeclaration = try parseEnumDeclaration()
        environment.addEnum(enumDeclaration)
        declarations.append(.enumDeclaration(enumDeclaration))
      default:
        let contractBehaviorDeclaration = try parseContractBehaviorDeclaration()
        declarations.append(.contractBehaviorDeclaration(contractBehaviorDeclaration))
      }
    }

    return declarations
  }
}

extension Parser {
  func parseIdentifier() throws -> Identifier {
    guard let token = currentToken, case .identifier(_) = token.kind else {
      throw ParserError.expectedToken(.identifier(""), sourceLocation: currentToken?.sourceLocation)
    }
    currentIndex += 1
    consumeNewLines()
    return Identifier(identifierToken: token)
  }

  func parseAttribute() throws -> Attribute {
    guard let token = currentToken, let attribute = Attribute(token: token) else {
      throw ParserError.expectedToken(.attribute(""), sourceLocation: currentToken?.sourceLocation)
    }
    currentIndex += 1
    consumeNewLines()
    return attribute
  }

  func parseLiteral() throws -> Token {
    guard let token = currentToken, case .literal(_) = token.kind else {
      throw ParserError.expectedToken(.literal(.string("")), sourceLocation: currentToken?.sourceLocation)
    }
    currentIndex += 1
    consumeNewLines()
    return token
  }

  func parseArrayLiteral() throws -> ArrayLiteral {
    let openSquareBracket = try consume(.punctuation(.openSquareBracket))

    var elements = [Expression]()

    var closeSquareBracket: Token?

    while let elementEnd = indexOfFirstAtCurrentDepth([.punctuation(.comma), .punctuation(.closeSquareBracket)]) {
      if let element = try? parseExpression(upTo: elementEnd) {
        let token = try consume(tokens[elementEnd].kind)
        if token.kind == .punctuation(.closeSquareBracket) { closeSquareBracket = token }
        elements.append(element)
      } else {
        break
      }
    }

    if elements.isEmpty {
      closeSquareBracket = try consume(.punctuation(.closeSquareBracket))
    }

    return ArrayLiteral(openSquareBracketToken: openSquareBracket, elements: elements, closeSquareBracketToken: closeSquareBracket!)
  }

  func parseRangeExpression() throws -> AST.RangeExpression {
    let startToken = try consume(.punctuation(.openBracket))
    let start = try parseLiteral()
    let op = try consume(anyOf: [.punctuation(.halfOpenRange), .punctuation(.closedRange)])
    let end = try parseLiteral()
    let endToken = try consume(.punctuation(.closeBracket))

    return AST.RangeExpression(startToken: startToken, endToken: endToken, initial: .literal(start), bound: .literal(end), op: op)
  }

  func parseDictionaryLiteral() throws -> AST.DictionaryLiteral {
    let openSquareBracket = try consume(.punctuation(.openSquareBracket))

    var elements = [AST.DictionaryLiteral.Entry]()

    var closeSquareBracket: Token?

    if let _ = try? consume(.punctuation(.colon)) {
      /// The dictionary literal doesn't contain any elements.

      closeSquareBracket = try consume(.punctuation(.closeSquareBracket))
      return AST.DictionaryLiteral(openSquareBracketToken: openSquareBracket, elements: elements, closeSquareBracketToken: closeSquareBracket!)
    }

    while let elementEnd = indexOfFirstAtCurrentDepth([.punctuation(.comma), .punctuation(.closeSquareBracket)]) {
      if let element = try? parseDictionaryElement(upTo: elementEnd) {
        let token = try consume(tokens[elementEnd].kind)
        if token.kind == .punctuation(.closeSquareBracket) { closeSquareBracket = token }
        elements.append(.init(key: element.0, value: element.1))
      } else {
        break
      }
    }

    if elements.isEmpty {
      closeSquareBracket = try consume(.punctuation(.closeSquareBracket))
    }

    return AST.DictionaryLiteral(openSquareBracketToken: openSquareBracket, elements: elements, closeSquareBracketToken: closeSquareBracket!)
  }

  func parseDictionaryElement(upTo commaIndex: Int) throws -> (Expression, Expression) {
    guard let colonIndex = indexOfFirstAtCurrentDepth([.punctuation(.comma)], maxIndex: commaIndex) else {
      throw ParserError.expectedToken(.punctuation(.comma), sourceLocation: currentToken?.sourceLocation)
    }

    let key = try parseExpression(upTo: colonIndex)
    try consume(.punctuation(.colon))
    let value = try parseExpression(upTo: commaIndex)

    return (key, value)
  }

  func parseInoutExpression() throws -> InoutExpression {
    let ampersandToken = try consume(.punctuation(.ampersand))

    guard let statementEndIndex = indexOfFirstAtCurrentDepth([.punctuation(.comma), .punctuation(.closeBracket)], maxIndex: tokens.count) else {
      throw ParserError.expectedToken(.punctuation(.comma), sourceLocation: currentToken?.sourceLocation)
    }

    let expression = try parseExpression(upTo: statementEndIndex)
    return InoutExpression(ampersandToken: ampersandToken, expression: expression)
  }

  func parseSelf() throws -> Token {
    guard let token = currentToken, case .self = token.kind else {
      throw ParserError.expectedToken(.self, sourceLocation: currentToken?.sourceLocation)
    }
    currentIndex += 1
    consumeNewLines()
    return token
  }

  func parseSubscriptExpression() throws -> SubscriptExpression {
    var base: SubscriptExpression

    let identifier = try parseIdentifier()
    try consume(.punctuation(.openSquareBracket))
    guard let index = indexOfFirstAtCurrentDepth([.punctuation(.closeSquareBracket)]) else {
      throw ParserError.expectedToken(.punctuation(.closeSquareBracket), sourceLocation: identifier.sourceLocation)
    }
    let indexExpression = try parseExpression(upTo: index)
    let closeSquareBracketToken = try consume(.punctuation(.closeSquareBracket))
    base = SubscriptExpression(baseExpression: .identifier(identifier), indexExpression: indexExpression, closeSquareBracketToken: closeSquareBracketToken)
    while let _ = try? consume(.punctuation(.openSquareBracket)) {
      guard let index = indexOfFirstAtCurrentDepth([.punctuation(.closeSquareBracket)]) else {
        throw ParserError.expectedToken(.punctuation(.closeSquareBracket), sourceLocation: identifier.sourceLocation)
      }
      let indexExpression = try parseExpression(upTo: index)
      let closeSquareBracketToken = try consume(.punctuation(.closeSquareBracket))
      base = SubscriptExpression(baseExpression: .subscriptExpression(base), indexExpression: indexExpression, closeSquareBracketToken: closeSquareBracketToken)
    }

    return base
  }

  func parseType() throws -> Type {
    if let openSquareBracketToken = attempt(try consume(.punctuation(.openSquareBracket))) {
      // The type is an array type or a dictionary type.
      let keyType = try parseType()
      if attempt(try consume(.punctuation(.colon))) != nil {
        // The type is a dictionary type.
        let valueType = try parseType()
        let closeSquareBracketToken = try consume(.punctuation(.closeSquareBracket))
        return Type(openSquareBracketToken: openSquareBracketToken, dictionaryWithKeyType: keyType, valueType: valueType, closeSquareBracketToken: closeSquareBracketToken)
      }

      let closeSquareBracketToken = try consume(.punctuation(.closeSquareBracket))
      return Type(openSquareBracketToken: openSquareBracketToken, arrayWithElementType: keyType, closeSquareBracketToken: closeSquareBracketToken)
    }

    if let inoutToken = attempt(try consume(.inout)) {
      // The type is declared inout (valid only for function parameters).
      let type = try parseType()
      return Type(ampersandToken: inoutToken, inoutType: type)
    }

    let identifier = try parseIdentifier()
    let type = Type(identifier: identifier)

    if attempt(try consume(.punctuation(.openSquareBracket))) != nil {
      // The type is a fixed-size array.

      // Get the array's size.
      let literal = try parseLiteral()

      // Ensure the literal is an integer.
      guard case .literal(.decimal(.integer(let size))) = literal.kind else {
        throw ParserError.expectedToken(.literal(.decimal(.integer(0))), sourceLocation: literal.sourceLocation)
      }

      let closeSquareBracketToken = try consume(.punctuation(.closeSquareBracket))
      return Type(fixedSizeArrayWithElementType: type, size: size, closeSquareBracketToken: closeSquareBracketToken)
    }

    if attempt(try consume(.punctuation(.openAngledBracket))) != nil {
      // The type has generic arguments.
      var genericArguments = [Type]()
      while true {
        let genericArgument = try parseType()
        genericArguments.append(genericArgument)

        // If the next token is not a comma, stop parsing generic arguments.
        if attempt(try consume(.punctuation(.comma))) == nil {
          break
        }
      }
      try consume(.punctuation(.closeAngledBracket))
      return Type(identifier: identifier, genericArguments: genericArguments)
    }

    return type
  }

  func parseTypeAnnotation() throws -> TypeAnnotation {
    let colonToken = try consume(.punctuation(.colon))
    let type = try parseType()
    return TypeAnnotation(colonToken: colonToken, type: type)
  }
}

extension Parser {
  func parseContractDeclaration() throws -> ContractDeclaration {
    let contractToken = try consume(.contract)
    let identifier = try parseIdentifier()
    let states = try? parseTypeStateGroup()
    try consume(.punctuation(.openBrace))
    let variableDeclarations = try parseVariableDeclarations(enclosingType: identifier.name)
    try consume(.punctuation(.closeBrace))

    return ContractDeclaration(contractToken: contractToken, identifier: identifier, states: states ?? [], variableDeclarations: variableDeclarations)
  }

  func parseVariableDeclarations(enclosingType: RawTypeIdentifier) throws -> [VariableDeclaration] {
    var variableDeclarations = [VariableDeclaration]()

    while let variableDeclaration = attempt(try parseVariableDeclaration(enclosingType: enclosingType)) {
      variableDeclarations.append(variableDeclaration)
    }

    return variableDeclarations
  }

  /// Parses the declaration of a variable, as a state property (in a type) or a local variable.
  /// If a type property is assigned a default expression value, the expression will be stored in the
  /// `VariableDeclaration` struct, where an assignment to a local variable will be represented as a `BinaryExpression`
  /// with an `=` operator.
  ///
  /// - Parameter enclosingType: The name of the type in which the variable is declared, if it is a state property.
  /// - Returns: The parsed `VariableDeclaration`.
  /// - Throws: If the token streams cannot be parsed as a `VariableDeclaration`.
  func parseVariableDeclaration(enclosingType: RawTypeIdentifier? = nil) throws -> VariableDeclaration {
    let isConstant: Bool

    let declarationToken: Token

    if let varToken = attempt(try consume(.var)) {
      declarationToken = varToken
      isConstant = false
    } else {
      let letToken = try consume(.let)
      declarationToken = letToken
      isConstant = true
    }

    var name = try parseIdentifier()
    let typeAnnotation = try parseTypeAnnotation()

    let assignedExpression: Expression?

    let asTypeProperty = enclosingType != nil

    // If we are parsing a state property defined in a type, and it has been assigned a default value, parse it.
    if asTypeProperty, let equalToken = attempt(try consume(.punctuation(.equal))) {
      guard let newLineIndex = indexOfFirstAtCurrentDepth([.newline]) else {
        throw ParserError.expectedToken(.newline, sourceLocation: equalToken.sourceLocation)
      }
      assignedExpression = try parseExpression(upTo: newLineIndex)
    } else {
      assignedExpression = nil
    }

    if let enclosingType = enclosingType {
      name.enclosingType = enclosingType
    }

    return VariableDeclaration(declarationToken: declarationToken, identifier: name, type: typeAnnotation.type, isConstant: isConstant, assignedExpression: assignedExpression)
  }
}

extension Parser {
  func parseContractBehaviorDeclaration() throws -> ContractBehaviorDeclaration {
    let contractIdentifier = try parseIdentifier()

    let _ = attempt(try consume(.punctuation(.at)))
    let states = try? parseTypeStateGroup()

    try consume(.punctuation(.doubleColon))

    let capabilityBinding = attempt(task: parseCapabilityBinding)
    let (callerCapabilities, closeBracketToken) = try parseCallerCapabilityGroup()
    try consume(.punctuation(.openBrace))

    let members = try parseContractBehaviorMembers(contractIdentifier: contractIdentifier.name)

    try consume(.punctuation(.closeBrace))

    for case .functionDeclaration(let functionDeclaration) in members {
      // Record all the function declarations.
      environment.addFunction(functionDeclaration, enclosingType: contractIdentifier.name, callerCapabilities: callerCapabilities)
    }

    return ContractBehaviorDeclaration(contractIdentifier: contractIdentifier, typeStates: states ?? [], capabilityBinding: capabilityBinding, callerCapabilities: callerCapabilities, closeBracketToken: closeBracketToken, members: members)
  }

  func parseCapabilityBinding() throws -> Identifier {
    let identifier = try parseIdentifier()
    try consume(.punctuation(.leftArrow))
    return identifier
  }

  func parseIdentifierGroup() throws -> (identifiers: [Identifier], closeBracketToken: Token) {
    try consume(.punctuation(.openBracket))
    let identifiers = try parseIdentifierList()
    let closeBracketToken = try consume(.punctuation(.closeBracket))

    return (identifiers, closeBracketToken)
  }

  func parseIdentifierList() throws -> [Identifier] {
    var identifiers = [Identifier]()
    repeat {
      identifiers.append(try parseIdentifier())
    } while attempt(try consume(.punctuation(.comma))) != nil

    return identifiers
  }

  func parseCallerCapabilityGroup() throws -> (callerCapabilities: [CallerCapability], closeBracketToken: Token) {
    let (identifiers, closeBracketToken) = try parseIdentifierGroup()
    let callerCapabilities = identifiers.map {
      return CallerCapability(identifier: $0)
    }

    return (callerCapabilities, closeBracketToken)
  }

  func parseTypeStateGroup() throws -> [TypeState] {
    let (identifiers, _) = try parseIdentifierGroup()
    let typeStates = identifiers.map {
      return TypeState(identifier: $0)
    }

    return typeStates
  }

  func parseContractBehaviorMembers(contractIdentifier: RawTypeIdentifier) throws -> [ContractBehaviorMember] {
    var members = [ContractBehaviorMember]()

    while true {
      if let functionDeclaration = attempt(task: parseFunctionDeclaration) {
        members.append(.functionDeclaration(functionDeclaration))
      } else if let initializerDeclaration = attempt(task: parseInitializerDeclaration) {
        members.append(.initializerDeclaration(initializerDeclaration))

        if initializerDeclaration.isPublic, environment.publicInitializer(forContract: contractIdentifier) == nil {
          // Record the public initializer, we will need to know if one of was declared during semantic analysis of the
          // contract's state properties.
          environment.setPublicInitializer(initializerDeclaration, forContract: contractIdentifier)
        }
      } else {
        break
      }
    }

    return members
  }

  func parseFunctionDeclaration() throws -> FunctionDeclaration {
    let (attributes, modifiers, funcToken) = try parseFunctionHead()
    let identifier = try parseIdentifier()
    let (parameters, closeBracketToken) = try parseParameters()
    let resultType = attempt(task: parseResult)
    let (body, closeBraceToken) = try parseCodeBlock()

    return FunctionDeclaration(funcToken: funcToken, attributes: attributes, modifiers: modifiers, identifier: identifier, parameters: parameters, closeBracketToken: closeBracketToken, resultType: resultType, body: body, closeBraceToken: closeBraceToken)
  }

  func parseInitializerDeclaration() throws -> InitializerDeclaration {
    let (attributes, modifiers, initToken) = try parseInitializerHead()
    let (parameters, closeBracketToken) = try parseParameters()
    let (body, closeBraceToken) = try parseCodeBlock()

    return InitializerDeclaration(initToken: initToken, attributes: attributes, modifiers: modifiers, parameters: parameters, closeBracketToken: closeBracketToken, body: body, closeBraceToken: closeBraceToken)
  }

  func parseAttributesAndModifiers() throws -> (attributes: [Attribute], modifiers: [Token]) {
    var attributes = [Attribute]()
    var modifiers = [Token]()

    // Parse function attributes such as @payable.
    while let attribute = attempt(task: parseAttribute) {
      attributes.append(attribute)
    }

    // Parse function modifiers.
    while true {
      if let token = attempt(try consume(.public)) {
        modifiers.append(token)
      } else if let token = attempt(try consume(.mutating)) {
        modifiers.append(token)
      } else {
        break
      }
    }

    return (attributes, modifiers)
  }

  func parseFunctionHead() throws -> (attributes: [Attribute], modifiers: [Token], funcToken: Token) {
    let (attributes, modifiers) = try parseAttributesAndModifiers()

    let funcToken = try consume(.func)
    return (attributes, modifiers, funcToken)
  }

  func parseInitializerHead() throws -> (attributes: [Attribute], modifiers: [Token], initToken: Token) {
    let (attributes, modifiers) = try parseAttributesAndModifiers()

    let initToken = try consume(.init)
    return (attributes, modifiers, initToken)
  }

  func parseParameters() throws -> ([Parameter], closeBracketToken: Token) {
    try consume(.punctuation(.openBracket))
    var parameters = [Parameter]()

    if let closeBracketToken = attempt(try consume(.punctuation(.closeBracket))) {
      return ([], closeBracketToken)
    }

    // Parse parameter declarations while the next token is a comma.
    repeat {
      let implicitToken = attempt(try consume(.implicit))
      let identifier = try parseIdentifier()
      let typeAnnotation = try parseTypeAnnotation()
      parameters.append(Parameter(identifier: identifier, type: typeAnnotation.type, implicitToken: implicitToken))
    } while attempt(try consume(.punctuation(.comma))) != nil

    let closeBracketToken = try consume(.punctuation(.closeBracket))
    return (parameters, closeBracketToken)
  }

  func parseResult() throws -> Type {
    try consume(.punctuation(.arrow))
    let identifier = try parseIdentifier()
    return Type(identifier: identifier)
  }

  func parseCodeBlock() throws -> ([Statement], closeBraceToken: Token) {
    try consume(.punctuation(.openBrace))
    let statements = try parseStatements()
    let closeBraceToken = try consume(.punctuation(.closeBrace))
    return (statements, closeBraceToken)
  }

  func parseStatements() throws -> [Statement] {
    var statements = [Statement]()

    while true {
      guard let statementEndIndex = indexOfFirstAtCurrentDepth([.punctuation(.semicolon), .newline, .punctuation(.closeBrace)], maxIndex: tokens.count) else {
        break
      }

      // A statement is either an expression, return statement, or if statement.

      if let expression = attempt(try parseExpression(upTo: statementEndIndex)) {
        statements.append(.expression(expression))
      } else if let returnStatement = attempt (try parseReturnStatement(statementEndIndex: statementEndIndex)) {
        statements.append(.returnStatement(returnStatement))
      } else if let becomeStatement = attempt (try parseBecomeStatement(statementEndIndex: statementEndIndex)) {
        statements.append(.becomeStatement(becomeStatement))
      } else if let forStatement = attempt(try parseForStatement()) {
        statements.append(.forStatement(forStatement))
      } else if let ifStatement = attempt(try parseIfStatement()) {
        statements.append(.ifStatement(ifStatement))
      } else {
        break
      }
      _ = try? consume(.punctuation(.semicolon))
      while (try? consume(.newline)) != nil {}
    }

    return statements
  }

  /// Parse an expression which ends one token before the one at `limitTokenIndex`.
  /// For instance in the expression `a + 2)`, and `limitTokenIndex` refers to the token `)`, the function will return
  /// the expression `a + 2`.
  ///
  /// - Parameter limitTokenIndex: The index of the token to parse up to.
  /// - Throws: If an expression couldn't be parsed.
  func parseExpression(upTo limitTokenIndex: Int) throws -> Expression {
    var binaryExpression: BinaryExpression? = nil

    guard limitTokenIndex >= currentIndex else {
      // limitTokenIndex should be smaller than the current token's index.
      throw ParserError.expectedToken(.literal(.decimal(.integer(0))), sourceLocation: currentToken?.sourceLocation)
    }

    // Try to parse the expression as the different types of Flint expressions.

    // Try to parse an expression passed by inout (e.g., '&a').
    if let inoutExpression = attempt(task: parseInoutExpression) {
      return .inoutExpression(inoutExpression)
    }

    // Try to parse a binary expression.
    // For each Flint binary operator, try to find it in the tokens ahead, and parse the tokens before and after as
    // the LHS and RHS expressions.
    for op in Token.Kind.Punctuation.allBinaryOperatorsByIncreasingPrecedence {
      guard let index = indexOfFirstAtCurrentDepth([.punctuation(op)], maxIndex: limitTokenIndex) else { continue }
      let lhs = try parseExpression(upTo: index)
      let operatorToken = try consume(.punctuation(op))
      let rhs = try parseExpression(upTo: limitTokenIndex)

      binaryExpression = BinaryExpression(lhs: lhs, op: operatorToken, rhs: rhs)
      break
    }

    // Return the binary expression if a valid one could be constructed.
    if let binExp = binaryExpression {
      return .binaryExpression(binExp)
    }

    // Try to parse a function call.
    if let functionCall = attempt(try parseFunctionCall()) {
      return .functionCall(functionCall)
    }

    // Try to parse an range.
    if let rangeExpression = attempt(task: parseRangeExpression) {
      return .range(rangeExpression)
    }

    // Try to parse an array literal.
    if let arrayLiteral = attempt(task: parseArrayLiteral) {
      return .arrayLiteral(arrayLiteral)
    }

    // Try to parse a dictionary literal.
    if let dictionaryLiteral = attempt(task: parseDictionaryLiteral) {
      return .dictionaryLiteral(dictionaryLiteral)
    }

    // Try to parse a literal.
    if let literal = attempt(task: parseLiteral) {
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
    if let `self` = attempt(task: parseSelf) {
      return .self(Token(kind: .self, sourceLocation: self.sourceLocation))
    }

    // Try to parse a subscript expression.
    if let subscriptExpression = attempt(try parseSubscriptExpression()) {
      return .subscriptExpression(subscriptExpression)
    }

    // If none of the previous expressions could be constructed, the expression is an identifier.
    let identifier = try parseIdentifier()
    return .identifier(identifier)
  }

  func parseBracketedExpression() throws -> Expression {
    try consume(.punctuation(.openBracket))
    guard let closeBracketIndex = indexOfFirstAtCurrentDepth([.punctuation(.closeBracket)]) else {
      throw ParserError.expectedToken(.punctuation(.closeBracket), sourceLocation: currentToken?.sourceLocation)
    }
    let expression = try parseExpression(upTo: closeBracketIndex)
    try consume(.punctuation(.closeBracket))

    return expression
  }

  func parseFunctionCall() throws -> FunctionCall {
    let identifier = try parseIdentifier()
    let (arguments, closeBracketToken) = try parseFunctionCallArgumentList()

    return FunctionCall(identifier: identifier, arguments: arguments, closeBracketToken: closeBracketToken)
  }

  func parseFunctionCallArgumentList() throws -> ([Expression], closeBracketToken: Token) {
    var arguments = [Expression]()

    try consume(.punctuation(.openBracket))

    var closeBracketToken: Token!

    while let argumentEnd = indexOfFirstAtCurrentDepth([.punctuation(.comma), .punctuation(.closeBracket)]) {
      if let argument = try? parseExpression(upTo: argumentEnd) {
        let token = try consume(tokens[argumentEnd].kind)
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
      closeBracketToken = try consume(.punctuation(.closeBracket))
    }

    return (arguments, closeBracketToken)
  }

  func parseReturnStatement(statementEndIndex: Int) throws -> ReturnStatement {
    let returnToken = try consume(.return)
    let expression = attempt(try parseExpression(upTo: statementEndIndex))
    return ReturnStatement(returnToken: returnToken, expression: expression)
  }

  func parseBecomeStatement(statementEndIndex: Int) throws -> BecomeStatement {
    let becomeToken = try consume(.become)
    let expression = try parseExpression(upTo: statementEndIndex)
    return BecomeStatement(becomeToken: becomeToken, expression: expression)
  }

  func parseIfStatement() throws -> IfStatement {
    let ifToken = try consume(.if)
    guard let nextOpenBraceIndex = indexOfFirstAtCurrentDepth([.punctuation(.openBrace)]) else {
      throw ParserError.expectedToken(.punctuation(.openBrace), sourceLocation: currentToken?.sourceLocation)
    }
    let condition = try parseExpression(upTo: nextOpenBraceIndex)
    let (statements, _) = try parseCodeBlock()
    let elseClauseStatements = (try? parseElseClause()) ?? []

    return IfStatement(ifToken: ifToken, condition: condition, statements: statements, elseClauseStatements: elseClauseStatements)
  }

  func parseForStatement() throws -> ForStatement {
    let forToken = try consume(.for)
    let variable = try parseVariableDeclaration()
    try consume(.in)

    guard let nextOpenBraceIndex = indexOfFirstAtCurrentDepth([.punctuation(.openBrace)]) else {
      throw ParserError.expectedToken(.punctuation(.openBrace), sourceLocation: currentToken?.sourceLocation)
    }
    let iterable = try parseExpression(upTo: nextOpenBraceIndex)
    let (statements, _) = try parseCodeBlock()

    return ForStatement(forToken: forToken, variable: variable, iterable: iterable, statements: statements)
  }

  func parseElseClause() throws -> [Statement] {
    try consume(.else)
    return try parseCodeBlock().0
  }
}


extension Parser {
  func parseStructDeclaration() throws -> StructDeclaration {
    let structToken = try consume(.struct)
    let identifier = try parseIdentifier()
    try consume(.punctuation(.openBrace))
    let members = try parseStructMembers(structIdentifier: identifier)
    try consume(.punctuation(.closeBrace))

    let structDeclaration = StructDeclaration(structToken: structToken, identifier: identifier, members: members)

    for member in structDeclaration.members {
      switch member {
      case .functionDeclaration(let functionDeclaration):
        environment.addFunction(functionDeclaration, enclosingType: identifier.name)
      case .initializerDeclaration(let initializerDeclaration):
        environment.addInitializer(initializerDeclaration, enclosingType: identifier.name)
      case .variableDeclaration(_): break
      }
    }

    return structDeclaration
  }

  func parseStructMembers(structIdentifier: Identifier) throws -> [StructMember] {
    var members = [StructMember]()
    while true {
      if let variableDeclaration = attempt(try parseVariableDeclaration(enclosingType: structIdentifier.name)) {
        members.append(.variableDeclaration(variableDeclaration))
      } else if let functionDeclaration = attempt(task: parseFunctionDeclaration) {
        members.append(.functionDeclaration(functionDeclaration))
      } else if let initializerDeclaration = attempt(task: parseInitializerDeclaration) {
        members.append(.initializerDeclaration(initializerDeclaration))
      } else {
        break
      }
    }

    return members
  }

}

extension Parser {
  func parseEnumDeclaration() throws -> EnumDeclaration {
    let enumToken = try consume(.enum)
    let identifier = try parseIdentifier()
    let typeAnnotation = try parseTypeAnnotation()
    try consume(.punctuation(.openBrace))
    let cases = try parseEnumCases(enumIdentifier: identifier, hiddenType: typeAnnotation.type)
    try consume(.punctuation(.closeBrace))
    
    return EnumDeclaration(enumToken: enumToken, identifier: identifier, type: typeAnnotation.type, cases: cases)
  }
  
  func parseEnumCases(enumIdentifier: Identifier, hiddenType: Type) throws -> [EnumCase] {
    var cases = [EnumCase]()
    while let enumCase = attempt(try parseEnumCase(enumIdentifier: enumIdentifier, hiddenType: hiddenType)) {
      cases.append(enumCase)
    }

    return cases
  }
  
  func parseEnumCase(enumIdentifier: Identifier, hiddenType: Type) throws -> EnumCase {
    let caseToken = try consume(.case)
    var identifier = try parseIdentifier()
    identifier.enclosingType = enumIdentifier.name
    var hiddenValue: Expression? = nil
    if attempt(try consume(.punctuation(.equal))) != nil {
      hiddenValue = try parseExpression(upTo: indexOfFirstAtCurrentDepth([.newline])!)
    }
    return EnumCase(caseToken: caseToken, identifier: identifier, type: Type(identifier: enumIdentifier), hiddenValue: hiddenValue, hiddenType: hiddenType)
  }
  
}

extension Parser {
  /// Finds the index of the first token in `targetTokens` which appears between the current token being processed and
  /// the token at `maxIndex`, at the same semantic nesting depth as the current token.
  ///
  /// E.g., if `targetTokens` is `[')']` and the list of remaining tokens is `f(g())` and `f` has index 0, the function
  /// will return the second `)`'s index, i.e. 5.
  ///
  /// - Parameters:
  ///   - targetTokens: The tokens being searched for.
  ///   - maxIndex: The index of the last token to inspect in the program's tokens.
  /// - Returns: The index of first token in `targetTokens` in the program's tokens.
  func indexOfFirstAtCurrentDepth(_ targetTokens: [Token.Kind], maxIndex: Int? = nil) -> Int? {
    let upperBound = maxIndex ?? tokens.count

    // The depth of the token, for each type of depth.
    var bracketDepth = 0
    var braceDepth = 0
    var squareBracketDepth = 0

    guard currentIndex <= upperBound else { return nil }

    let range = (currentIndex..<upperBound)

    // If the brace depth is negative, the program is malformed.
    for index in range where braceDepth >= 0 {
      let token = tokens[index].kind

      // If we found a limit token and all the depths are 0 (at the same level the initial token was at), return its
      // index.
      if targetTokens.contains(token), bracketDepth == 0, braceDepth == 0, squareBracketDepth == 0 {
        return index
      }

      // Update the depths depending on the token.
      if case .punctuation(let punctuation) = token {
        switch punctuation {
        case .openBracket: bracketDepth += 1
        case .closeBracket: bracketDepth -= 1
        case .openBrace: braceDepth += 1
        case .closeBrace: braceDepth -= 1
        case .openSquareBracket: squareBracketDepth += 1
        case .closeSquareBracket: squareBracketDepth -= 1
        default: continue
        }
      }
    }

    return nil
  }
}

/// An error during parsing.
///
/// - expectedToken: The current token did not match the token we expected.
enum ParserError: Error {
  case expectedToken(Token.Kind, sourceLocation: SourceLocation?)
  case expectedTokens([Token.Kind], sourceLocation: SourceLocation?)
}
