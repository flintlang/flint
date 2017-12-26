//
//  BranchingTest.swift
//  ParserTests
//
//  Created by Franklin Schrans on 12/25/17.
//

import XCTest
@testable import Parser
import AST

class BranchingTest: XCTestCase, ParserTest {
  var tokens: [Token] =
    [.contract, .identifier("Wallet"), .punctuation(.openBrace), .newline, .var, .identifier("owner"), .punctuation(.colon), .identifier("Address"), .newline, .var, .identifier("contents"), .punctuation(.colon), .identifier("Ether"), .newline, .punctuation(.closeBrace), .newline, .newline, .identifier("Wallet"), .punctuation(.doubleColon), .punctuation(.openBracket), .identifier("any"), .punctuation(.closeBracket), .punctuation(.openBrace), .newline, .func, .identifier("factorial"), .punctuation(.openBracket), .identifier("n"), .punctuation(.colon), .identifier("Int"), .punctuation(.closeBracket), .punctuation(.arrow), .identifier("Int"), .punctuation(.openBrace), .newline, .if, .punctuation(.openBracket), .identifier("n"), .binaryOperator(.lessThan), .literal(.decimal(.integer(2))), .punctuation(.closeBracket), .punctuation(.openBrace), .return, .literal(.decimal(.integer(0))), .punctuation(.closeBrace), .newline, .newline, .return, .identifier("n"), .binaryOperator(.times), .identifier("factorial"), .punctuation(.openBracket), .identifier("n"), .binaryOperator(.minus), .literal(.decimal(.integer(1))), .punctuation(.closeBracket), .newline, .punctuation(.closeBrace), .newline, .newline, .func, .identifier("foo"), .punctuation(.openBracket), .punctuation(.closeBracket), .punctuation(.openBrace), .newline, .if, .literal(.boolean(.true)), .punctuation(.openBrace), .identifier("print"), .punctuation(.openBracket), .literal(.string("error")), .punctuation(.closeBracket), .punctuation(.semicolon), .return, .punctuation(.semicolon), .punctuation(.closeBrace), .newline, .punctuation(.closeBrace), .newline, .punctuation(.closeBrace)]

  var expectedAST: TopLevelModule =
  TopLevelModule(declarations: [TopLevelDeclaration.contractDeclaration(ContractDeclaration(identifier: Identifier(name: "Wallet"), variableDeclarations: [VariableDeclaration(identifier: Identifier(name: "owner"), type: Type(name: "Address")), VariableDeclaration(identifier: Identifier(name: "contents"), type: Type(name: "Ether"))])), TopLevelDeclaration.contractBehaviorDeclaration(ContractBehaviorDeclaration(contractIdentifier: Identifier(name: "Wallet"), callerCapabilities: [CallerCapability(name: "any")], functionDeclarations: [FunctionDeclaration(modifiers: [], identifier: Identifier(name: "factorial"), parameters: [Parameter(identifier: Identifier(name: "n"), type: Type(name: "Int"))], resultType: Optional(Type(name: "Int")), body: [Statement.ifStatement(IfStatement(condition: Expression.bracketedExpression(Expression.binaryExpression(BinaryExpression(lhs: Expression.identifier(Identifier(name: "n")), op: Token.BinaryOperator.lessThan, rhs: Expression.literal(Token.Literal.decimal(Token.DecimalLiteral.integer(2)))))), statements: [Statement.returnStatement(ReturnStatement(expression: Optional(Expression.literal(Token.Literal.decimal(Token.DecimalLiteral.integer(0))))))], elseClauseStatements: [])), Statement.returnStatement(ReturnStatement(expression: Optional(Expression.binaryExpression(BinaryExpression(lhs: Expression.identifier(Identifier(name: "n")), op: Token.BinaryOperator.times, rhs: Expression.functionCall(FunctionCall(identifier: Identifier(name: "factorial"), arguments: [Expression.binaryExpression(BinaryExpression(lhs: Expression.identifier(Identifier(name: "n")), op: Token.BinaryOperator.minus, rhs: Expression.literal(Token.Literal.decimal(Token.DecimalLiteral.integer(1)))))])))))))]), FunctionDeclaration(modifiers: [], identifier: Identifier(name: "foo"), parameters: [], resultType: nil, body: [Statement.ifStatement(IfStatement(condition: Expression.literal(Token.Literal.boolean(Token.BooleanLiteral.true)), statements: [Statement.expression(Expression.functionCall(FunctionCall(identifier: Identifier(name: "print"), arguments: [Expression.literal(Token.Literal.string("error"))]))), Statement.returnStatement(ReturnStatement(expression: nil))], elseClauseStatements: []))])]))])

  func testBranching() {
    test()
  }
}
