//
//  Compiler.swift
//  etherlangPackageDescription
//
//  Created by Franklin Schrans on 12/19/17.
//

import Foundation
import AST
import Diagnostic

public class Parser {
  var tokens: [Token]

  var currentIndex: Int

  var currentToken: Token? {
    return currentIndex < tokens.count ? tokens[currentIndex] : nil
  }

  var context = Context()
  var diagnostics = [Diagnostic]()
  
  public init(tokens: [Token]) {
    self.tokens = tokens
    self.currentIndex = tokens.startIndex
  }
  
  public func parse() -> (TopLevelModule?, Context, [Diagnostic]) {
    do {
      return (try parseTopLevelModule(), context, [])
    } catch ParserError.expectedToken(let tokenKind, sourceLocation: let sourceLocation) {
      return (nil, context, diagnostics + [Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected token \(tokenKind)")])
    } catch {
      fatalError()
    }
  }

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

  func consumeNewLines() {
    while currentIndex < tokens.count, tokens[currentIndex].kind == .newline {
      currentIndex += 1
    }
  }

  func attempt<ReturnType>(_ task: () throws -> ReturnType) -> ReturnType? {
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
    let topLevelDeclarations = try parseTopLevelDeclarations()
    return TopLevelModule(declarations: topLevelDeclarations)
  }
  
  func parseTopLevelDeclarations() throws -> [TopLevelDeclaration] {
    var declarations = [TopLevelDeclaration]()
    
    while true {
      guard let first = currentToken else { break }
      if first.kind == .contract {
        let contractDeclaration = try parseContractDeclaration()
        context.declaredContractsIdentifiers.append(contractDeclaration.identifier)
        declarations.append(.contractDeclaration(contractDeclaration))
      } else {
        let contractBehaviorDeclaration = try parseContractBehaviorDeclaration()
        declarations.append(.contractBehaviorDeclaration(contractBehaviorDeclaration))
      }
    }
    
    return declarations
  }
}

extension Parser {
  func parseIdentifier() throws -> Identifier {
    guard let token = currentToken, case .identifier(let name) = token.kind else {
      throw ParserError.expectedToken(.identifier(""), sourceLocation: currentToken?.sourceLocation)
    }
    currentIndex += 1
    consumeNewLines()
    return Identifier(name: name, sourceLocation: token.sourceLocation)
  }

  func parseLiteral() throws -> Token {
    guard let token = currentToken, case .literal(_) = token.kind else {
      throw ParserError.expectedToken(.literal(.string("")), sourceLocation: currentToken?.sourceLocation)
    }
    currentIndex += 1
    consumeNewLines()
    return token
  }

  func parseSelf() throws -> Token {
    guard let token = currentToken, case .self = token.kind else {
      throw ParserError.expectedToken(.self, sourceLocation: currentToken?.sourceLocation)
    }
    currentIndex += 1
    consumeNewLines()
    return token
  }

  func parseArrayAccess(scopeContext: ScopeContext) throws -> ArrayAccess {
    let identifier = try parseIdentifier()
    try consume(.punctuation(.openSquareBracket))
    guard let index = indexOfFirstAtCurrentDepth([.punctuation(.closeSquareBracket)]) else {
      throw ParserError.expectedToken(.punctuation(.closeSquareBracket), sourceLocation: identifier.sourceLocation)
    }
    let (indexExpression, _) = try parseExpression(upTo: index, scopeContext: scopeContext)
    try consume(.punctuation(.closeSquareBracket))

    return ArrayAccess(arrayIdentifier: identifier, indexExpression: indexExpression, sourceLocation: identifier.sourceLocation)
  }
  
  func parseType() throws -> Type {
    if let openBracketToken = attempt({ try consume(.punctuation(.openSquareBracket)) }) {
      let type = try parseType()
      try consume(.punctuation(.closeSquareBracket))
      return Type(arrayWithElementType: type.rawType, sourceLocation: openBracketToken.sourceLocation)
    }

    guard let first = currentToken, case .identifier(let name) = first.kind else {
      throw ParserError.expectedToken(.identifier(""), sourceLocation: currentToken?.sourceLocation)
    }
    
    currentIndex += 1
    consumeNewLines()
    return Type(name: name, sourceLocation: first.sourceLocation)
  }
  
  func parseTypeAnnotation() throws -> TypeAnnotation {
    try consume(.punctuation(.colon))
    let type = try parseType()
    return TypeAnnotation(type: type, sourceLocation: type.sourceLocation)
  }
}

extension Parser {
  func parseContractDeclaration() throws -> ContractDeclaration {
    let contractToken = try consume(.contract)
    let identifier = try parseIdentifier()
    try consume(.punctuation(.openBrace))
    let variableDeclarations = try parseVariableDeclarations()
    try consume(.punctuation(.closeBrace))

    context.contractVariablesMap[identifier, default: []].append(contentsOf: variableDeclarations)
    
    return ContractDeclaration(identifier: identifier, variableDeclarations: variableDeclarations, sourceLocation: contractToken.sourceLocation)
  }
  
  func parseVariableDeclarations() throws -> [VariableDeclaration] {
    var variableDeclarations = [VariableDeclaration]()
    
    while let variableDeclaration = attempt(parseVariableDeclaration) {
      variableDeclarations.append(variableDeclaration)
    }
    
    return variableDeclarations
  }

  func parseVariableDeclaration() throws -> VariableDeclaration {
    let varToken = try consume(.var)
    let name = try parseIdentifier()
    let typeAnnotation = try parseTypeAnnotation()
    return VariableDeclaration(identifier: name, type: typeAnnotation.type, sourceLocation: varToken.sourceLocation)
  }
}

extension Parser {
  func parseContractBehaviorDeclaration() throws -> ContractBehaviorDeclaration {
    let contractIdentifier = try parseIdentifier()
    try consume(.punctuation(.doubleColon))
    let callerCapabilities = try parseCallerCapabilityGroup()
    try consume(.punctuation(.openBrace))
    let functionDeclarations = try parseFunctionDeclarations()
    try consume(.punctuation(.closeBrace))

    for functionDeclaration in functionDeclarations {
      context.functions.append(functionDeclaration.mangled(inContract: contractIdentifier, withCallerCapabilities: callerCapabilities))
    }
    
    return ContractBehaviorDeclaration(contractIdentifier: contractIdentifier, callerCapabilities: callerCapabilities, functionDeclarations: functionDeclarations, sourceLocation: contractIdentifier.sourceLocation)
  }
  
  func parseCallerCapabilityGroup() throws -> [CallerCapability] {
    try consume(.punctuation(.openBracket))
    let callerCapabilities = try parseCallerCapabilityList()
    try consume(.punctuation(.closeBracket))
    
    return callerCapabilities
  }
  
  func parseCallerCapabilityList() throws -> [CallerCapability] {
    var callerCapabilities = [CallerCapability]()
    repeat {
      let identifier = try parseIdentifier()
      callerCapabilities.append(CallerCapability(name: identifier.name, sourceLocation: identifier.sourceLocation))
    } while (attempt { try consume(.punctuation(.comma)) }) != nil
    
    return callerCapabilities
  }
  
  func parseFunctionDeclarations() throws -> [FunctionDeclaration] {
    var functionDeclarations = [FunctionDeclaration]()
    
    while let (modifiers, funcToken) = attempt(parseFunctionHead) {
      let identifier = try parseIdentifier()
      let parameters = try parseParameters()
      let resultType = attempt(parseResult)

      let scopeContext = ScopeContext(localVariables: parameters.map { $0.identifier })
      let body = try parseCodeBlock(scopeContext: scopeContext)
      
      let functionDeclaration = FunctionDeclaration(modifiers: modifiers, identifier: identifier, parameters: parameters, resultType: resultType, body: body, sourceLocation: modifiers.first?.sourceLocation ?? funcToken.sourceLocation)
      functionDeclarations.append(functionDeclaration)
    }
    
    return functionDeclarations
  }
  
  func parseFunctionHead() throws -> ([Token], funcToken: Token) {
    var modifiers = [Token]()
    
    while true {
      if let token = attempt({ try consume(.public) }) {
        modifiers.append(token)
      } else if let token = attempt({ try consume(.mutating) }) {
        modifiers.append(token)
      } else {
        break
      }
    }
    
    let funcToken = try consume(.func)
    return (modifiers, funcToken)
  }
  
  func parseParameters() throws -> [Parameter] {
    try consume(.punctuation(.openBracket))
    var parameters = [Parameter]()
    
    if (attempt { try consume(.punctuation(.closeBracket)) }) != nil {
      return []
    }
    
    repeat {
      let identifier = try parseIdentifier()
      let typeAnnotation = try parseTypeAnnotation()
      parameters.append(Parameter(identifier: identifier, type: typeAnnotation.type, sourceLocation: identifier.sourceLocation))
    } while (attempt { try consume(.punctuation(.comma)) }) != nil
    
    try consume(.punctuation(.closeBracket))
    return parameters
  }
  
  func parseResult() throws -> Type {
    try consume(.punctuation(.arrow))
    let identifier = try parseIdentifier()
    return Type(name: identifier.name, sourceLocation: identifier.sourceLocation)
  }
  
  func parseCodeBlock(scopeContext: ScopeContext) throws -> [Statement] {
    try consume(.punctuation(.openBrace))
    let statements = try parseStatements(scopeContext: scopeContext)
    try consume(.punctuation(.closeBrace))
    return statements
  }
  
  func parseStatements(scopeContext: ScopeContext) throws -> [Statement] {
    var statements = [Statement]()

    var scopeContext = scopeContext
    
    while true {
      guard let statementEndIndex = indexOfFirstAtCurrentDepth([.punctuation(.semicolon), .newline, .punctuation(.closeBrace)], maxIndex: tokens.count) else {
        break
      }

      if let (expression, expressionScopeContext) = attempt({ try parseExpression(upTo: statementEndIndex, scopeContext: scopeContext) }) {
        scopeContext.merge(with: expressionScopeContext)
        statements.append(.expression(expression))
      } else if let returnStatement = attempt ({ try parseReturnStatement(statementEndIndex: statementEndIndex, scopeContext: scopeContext) }) {
        statements.append(.returnStatement(returnStatement))
      } else if let ifStatement = attempt({ try parseIfStatement(scopeContext: scopeContext) }) {
        statements.append(.ifStatement(ifStatement))
      } else {
        break
      }
      _ = try? consume(.punctuation(.semicolon))
      while (try? consume(.newline)) != nil {}
    }
    
    return statements
  }
  
  func parseExpression(upTo limitTokenIndex: Int, scopeContext: ScopeContext) throws -> (Expression, ScopeContext) {
    var binaryExpression: BinaryExpression? = nil
    var scopeContext = scopeContext

    for op in Token.Kind.BinaryOperator.allByIncreasingPrecedence {
      guard let index = indexOfFirstAtCurrentDepth([.binaryOperator(op)], maxIndex: limitTokenIndex) else { continue }
      let (lhs, lhsScopeContext) = try parseExpression(upTo: index, scopeContext: scopeContext)
      let operatorToken = try consume(.binaryOperator(op))
      let (rhs, _) = try parseExpression(upTo: limitTokenIndex, scopeContext: scopeContext)
      scopeContext.merge(with: lhsScopeContext)
      binaryExpression = BinaryExpression(lhs: lhs, op: operatorToken, rhs: rhs, sourceLocation: lhs.sourceLocation)
      break
    }
    
    if let binExp = binaryExpression {
      return (.binaryExpression(binExp), scopeContext)
    }

    if let functionCall = attempt( { try parseFunctionCall(scopeContext: scopeContext) }) {
      return (.functionCall(functionCall), scopeContext)
    }

    if let literal = attempt(parseLiteral) {
      return (.literal(literal), scopeContext)
    }

    if let variableDeclaration = attempt(parseVariableDeclaration) {
      scopeContext.addLocalVariable(variableDeclaration.identifier)
      return (.variableDeclaration(variableDeclaration), scopeContext)
    }

    if let bracketedExpression = attempt({ try parseBracketedExpression(scopeContext: scopeContext) }) {
      return (.bracketedExpression(bracketedExpression), scopeContext)
    }

    if let `self` = attempt(parseSelf) {
      return (.self(Token(kind: .self, sourceLocation: self.sourceLocation)), scopeContext)
    }

    if var arrayAccess = attempt({ try parseArrayAccess(scopeContext: scopeContext) }) {
      if !scopeContext.contains(localVariable: arrayAccess.arrayIdentifier.name) {
        arrayAccess.arrayIdentifier.isImplicitPropertyAccess = true
      }
      return (.arrayAccess(arrayAccess), scopeContext)
    }

    var identifier = try parseIdentifier()
    if !scopeContext.contains(localVariable: identifier.name) {
      identifier.isImplicitPropertyAccess = true
    }
    return (.identifier(identifier), scopeContext)
  }

  func parseBracketedExpression(scopeContext: ScopeContext) throws -> Expression {
    try consume(.punctuation(.openBracket))
    guard let closeBracketIndex = indexOfFirstAtCurrentDepth([.punctuation(.closeBracket)]) else {
      throw ParserError.expectedToken(.punctuation(.closeBracket), sourceLocation: currentToken?.sourceLocation)
    }
    let (expression, _) = try parseExpression(upTo: closeBracketIndex, scopeContext: scopeContext)
    try consume(.punctuation(.closeBracket))

    return expression
  }

  func parseFunctionCall(scopeContext: ScopeContext) throws -> FunctionCall {
    let identifier = try parseIdentifier()
    let arguments = try parseFunctionCallArgumentList(scopeContext: scopeContext)

    return FunctionCall(identifier: identifier, arguments: arguments, sourceLocation: identifier.sourceLocation)
  }

  func parseFunctionCallArgumentList(scopeContext: ScopeContext) throws -> [Expression] {
    var arguments = [Expression]()

    try consume(.punctuation(.openBracket))

    while let argumentEnd = indexOfFirstAtCurrentDepth([.punctuation(.comma), .punctuation(.closeBracket)]) {
      if let (argument, _) = try? parseExpression(upTo: argumentEnd, scopeContext: scopeContext) {
        try consume(tokens[argumentEnd].kind)
        arguments.append(argument)
      } else {
        break
      }
    }

    if arguments.isEmpty {
      try consume(.punctuation(.closeBracket))
    }

    return arguments
  }
  
  func parseReturnStatement(statementEndIndex: Int, scopeContext: ScopeContext) throws -> ReturnStatement {
    let returnToken = try consume(.return)
    let expression = attempt { try parseExpression(upTo: statementEndIndex, scopeContext: scopeContext) }?.0
    return ReturnStatement(expression: expression, sourceLocation: returnToken.sourceLocation)
  }

  func parseIfStatement(scopeContext: ScopeContext) throws -> IfStatement {
    let ifToken = try consume(.if)
    guard let nextOpenBraceIndex = indexOfFirstAtCurrentDepth([.punctuation(.openBrace)]) else {
      throw ParserError.expectedToken(.punctuation(.openBrace), sourceLocation: currentToken?.sourceLocation)
    }
    let (condition, _) = try parseExpression(upTo: nextOpenBraceIndex, scopeContext: scopeContext)
    let statements = try parseCodeBlock(scopeContext: scopeContext)
    let elseClauseStatements = (try? parseElseClause(scopeContext: scopeContext)) ?? []

    return IfStatement(condition: condition, statements: statements, elseClauseStatements: elseClauseStatements, sourceLocation: ifToken.sourceLocation)
  }

  func parseElseClause(scopeContext: ScopeContext) throws -> [Statement] {
    try consume(.else)
    return try parseCodeBlock(scopeContext: scopeContext)
  }
}

extension Parser {
  func indexOfFirstAtCurrentDepth(_ limitTokens: [Token.Kind], maxIndex: Int? = nil) -> Int? {
    let upperBound = maxIndex ?? tokens.count

    var bracketDepth = 0
    var braceDepth = 0
    var squareBracketDepth = 0

    let range = (currentIndex..<upperBound)
    for index in range where braceDepth >= 0 {
      let token = tokens[index].kind

      if limitTokens.contains(token) {
        if bracketDepth == 0 && squareBracketDepth == 0 { return index }
      }
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

enum ParserError: Error {
  case expectedToken(Token.Kind, sourceLocation: SourceLocation?)
}
