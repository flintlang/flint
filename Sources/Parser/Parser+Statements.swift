//
//  Parser+Statements.swift
//  Parser
//
//  Created by Hails, Daniel R on 03/09/2018.
//

import AST
import Lexer

extension Parser {
  // MARK: Statements
  func parseStatements() throws -> [Statement] {
    var statements = [Statement]()
    endStatement: while let first = currentToken {
      switch first.kind {
      case .punctuation(.semicolon), .newline:
        currentIndex+=1
     // Valid starting tokens for statements
      case .return, .become, .emit, .for, .if, .identifier, .punctuation(.ampersand), .punctuation(.openSquareBracket),
           .punctuation(.openBracket), .self, .var, .let, .public, .visible, .mutating, .try:
        statements.append(try parseStatement())
      default:
        break endStatement
      }
    }
    return statements
  }

  func parseStatement() throws -> Statement {
    guard let first = currentToken else {
      throw raise(.unexpectedEOF())
    }

    guard let statementEndIndex = indexOfFirstAtCurrentDepth(
      [
        .punctuation(.semicolon),
        .newline,
        .punctuation(.closeBrace)
      ],
      maxIndex: tokens.count) else {
      throw raise(.statementSameLine(at: latestSource))
    }
    let statement: Statement
    // The statement can be either a return, become, for, if or expression statement
    switch first.kind {
    case .return:
      let returnStatement = try parseReturnStatement(statementEndIndex: statementEndIndex)
      statement = .returnStatement(returnStatement)
    case .become:
      let becomeStatement = try parseBecomeStatement(statementEndIndex: statementEndIndex)
      statement = .becomeStatement(becomeStatement)
    case .emit:
      let emitStatement = try parseEmitStatement(statementEndIndex: statementEndIndex)
      statement = .emitStatement(emitStatement)
    case .for:
      let forStatement = try parseForStatement()
      statement = .forStatement(forStatement)
    case .if:
      let ifStatement = try parseIfStatement()
      statement = .ifStatement(ifStatement)
    // Valid starting tokens for expressions
    case .identifier, .punctuation(.ampersand), .punctuation(.openSquareBracket),
         .punctuation(.openBracket), .self, .var, .let, .public, .visible, .mutating, .try:
      let expression = try parseExpression(upTo: statementEndIndex)
      statement = .expression(expression)
    default:
      throw raise(.expectedStatement(at: latestSource))
    }

    return statement
  }

  func parseCodeBlock() throws -> ([Statement], closeBraceToken: Token) {
    try consume(.punctuation(.openBrace), or: .leftBraceExpected(in: "code block", at: latestSource))
    let statements = try parseStatements()
    let closeBraceToken = try consume(.punctuation(.closeBrace),
                                      or: .rightBraceExpected(in: "code block", at: latestSource))
    return (statements, closeBraceToken)
  }

  func parseReturnStatement(statementEndIndex: Int) throws -> ReturnStatement {
    let returnToken = try consume(.return, or: .expectedStatement(at: latestSource))
    var expression: Expression?
    if currentToken?.kind != .newline {
      expression = try parseExpression(upTo: statementEndIndex)
    }
    return ReturnStatement(returnToken: returnToken, expression: expression)
  }

  func parseBecomeStatement(statementEndIndex: Int) throws -> BecomeStatement {
    let becomeToken = try consume(.become, or: .expectedStatement(at: latestSource))
    let expression = try parseExpression(upTo: statementEndIndex)
    return BecomeStatement(becomeToken: becomeToken, expression: expression)
  }

  func parseEmitStatement(statementEndIndex: Int) throws -> EmitStatement {
    let token = try consume(.emit, or: .expectedStatement(at: latestSource))
    let expression = try parseExpression(upTo: statementEndIndex)
    return EmitStatement(emitToken: token, expression: expression)
  }

  func parseIfStatement() throws -> IfStatement {
    let ifToken = try consume(.if, or: .expectedStatement(at: latestSource))
    guard let nextOpenBraceIndex = indexOfFirstAtCurrentDepth([.punctuation(.openBrace)]) else {
      throw raise(.rightBraceExpected(in: "if statement", at: latestSource))
    }
    let condition = try parseExpression(upTo: nextOpenBraceIndex)
    let (statements, _) = try parseCodeBlock()
    var elseClauseStatements = [Statement]()
    if currentToken?.kind == .else {
      elseClauseStatements = try parseElseClause()
    }

    return IfStatement(ifToken: ifToken,
                       condition: condition,
                       statements: statements,
                       elseClauseStatements: elseClauseStatements)
  }

  func parseElseClause() throws -> [Statement] {
    try consume(.else, or: .expectedStatement(at: latestSource))
    return try parseCodeBlock().0
  }

  func parseForStatement() throws -> ForStatement {
    let forToken = try consume(.for, or: .expectedStatement(at: latestSource))
    guard let nextOpenBraceIndex = indexOfFirstAtCurrentDepth([.punctuation(.openBrace)]) else {
      throw raise(.leftBraceExpected(in: "For Statement", at: latestSource))
    }
    guard let inIndex = indexOfFirstAtCurrentDepth([.in], maxIndex: nextOpenBraceIndex) else {
      throw raise(.expectedForInStatement(at: latestSource))
    }
    let variable = try parseVariableDeclaration(modifiers: [], upTo: inIndex)
    try consume(.in, or: .expectedForInStatement(at: latestSource))

    let iterable = try parseExpression(upTo: nextOpenBraceIndex)
    let (statements, _) = try parseCodeBlock()

    return ForStatement(forToken: forToken, variable: variable, iterable: iterable, statements: statements)
  }

}
