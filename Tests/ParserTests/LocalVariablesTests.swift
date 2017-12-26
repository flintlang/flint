//
//  LiteralTests.swift
//  ParserTests
//
//  Created by Franklin Schrans on 12/24/17.
//

import XCTest
@testable import Parser
import AST

class LiteralTest: XCTestCase, ParserTest {
  var tokens: [Token] = [.identifier("Test"), .punctuation(.doubleColon), .punctuation(.openBracket), .identifier("any"), .punctuation(.closeBracket), .punctuation(.openBrace), .newline, .func, .identifier("foo"), .punctuation(.openBracket), .punctuation(.closeBracket), .punctuation(.arrow), .identifier("Bool"), .punctuation(.openBrace), .newline, .var, .identifier("a"), .punctuation(.colon), .identifier("Int"), .binaryOperator(.equal), .literal(.decimal(.integer(2))), .binaryOperator(.plus), .literal(.decimal(.real(4, 564))), .punctuation(.semicolon), .newline, .var, .identifier("b"), .punctuation(.colon), .identifier("String"), .binaryOperator(.equal), .literal(.string("hello")), .binaryOperator(.plus), .literal(.string(" world")), .punctuation(.semicolon), .newline, .return, .literal(.boolean(.false)), .punctuation(.semicolon), .newline, .punctuation(.closeBrace), .newline, .punctuation(.closeBrace)]

  var expectedAST: TopLevelModule =
    TopLevelModule(declarations: [TopLevelDeclaration.contractBehaviorDeclaration(ContractBehaviorDeclaration(contractIdentifier: Identifier(name: "Test"), callerCapabilities: [CallerCapability(name: "any")], functionDeclarations: [FunctionDeclaration(modifiers: [], identifier: Identifier(name: "foo"), parameters: [], resultType: Optional(Type(name: "Bool")), body: [Statement.expression(Expression.binaryExpression(BinaryExpression(lhs: Expression.variableDeclaration(VariableDeclaration(identifier: Identifier(name: "a"), type: Type(name: "Int"))), op: Token.BinaryOperator.equal, rhs: Expression.binaryExpression(BinaryExpression(lhs: Expression.literal(Token.Literal.decimal(Token.DecimalLiteral.integer(2))), op: Token.BinaryOperator.plus, rhs: Expression.literal(Token.Literal.decimal(Token.DecimalLiteral.real(4, 564)))))))), Statement.expression(Expression.binaryExpression(BinaryExpression(lhs: Expression.variableDeclaration(VariableDeclaration(identifier: Identifier(name: "b"), type: Type(name: "String"))), op: Token.BinaryOperator.equal, rhs: Expression.binaryExpression(BinaryExpression(lhs: Expression.literal(Token.Literal.string("hello")), op: Token.BinaryOperator.plus, rhs: Expression.literal(Token.Literal.string(" world"))))))), Statement.returnStatement(ReturnStatement(expression: Expression.literal(Token.Literal.boolean(Token.BooleanLiteral.false))))])]))])

  func testLocalVariables() {
    test()
  }
}

