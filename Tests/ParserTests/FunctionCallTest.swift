//
//  FunctionCallTest.swift
//  ParserTests
//
//  Created by Franklin Schrans on 12/22/17.
//

import XCTest
@testable import Parser

class FunctionCallTest: XCTestCase, ParserTest {
  var tokens: [Token] = [
    .identifier("Test"), .punctuation(.doubleColon), .punctuation(.openBracket), .identifier("any"), .punctuation(.closeBracket), .punctuation(.openBrace), .func, .identifier("foo"), .punctuation(.openBracket), .identifier("a"), .punctuation(.colon), .identifier("Int"), .punctuation(.closeBracket), .punctuation(.openBrace), .identifier("foo"), .punctuation(.openBracket), .identifier("bar"), .punctuation(.openBracket), .identifier("1"), .punctuation(.comma), .identifier("2"), .punctuation(.closeBracket), .punctuation(.comma), .identifier("3"), .punctuation(.comma), .identifier("5"), .binaryOperator(.plus), .identifier("bar"), .punctuation(.openBracket), .identifier("4"), .punctuation(.comma), .identifier("6"), .punctuation(.closeBracket), .punctuation(.closeBracket), .punctuation(.semicolon), .punctuation(.closeBrace), .func, .identifier("bar"), .punctuation(.openBracket), .identifier("a"), .punctuation(.colon), .identifier("Int"), .punctuation(.comma), .identifier("b"), .punctuation(.colon), .identifier("Int"), .punctuation(.closeBracket), .punctuation(.arrow), .identifier("Int"), .punctuation(.openBrace), .return, .identifier("a"), .binaryOperator(.plus), .identifier("b"), .punctuation(.semicolon), .punctuation(.closeBrace), .punctuation(.closeBrace)
  ]

  var expectedAST: TopLevelModule =
    TopLevelModule(declarations: [.contractBehaviorDeclaration(ContractBehaviorDeclaration(contractIdentifier: Identifier(name: "Test"), callerCapabilities: [CallerCapability(name: "any")], functionDeclarations: [FunctionDeclaration(modifiers: [], identifier: Identifier(name: "foo"), parameters: [Parameter(identifier: Identifier(name: "a"), type: Type(name: "Int"))], resultType: nil, body: [Statement.expression(Expression.functionCall(FunctionCall(identifier: Identifier(name: "foo"), arguments: [Expression.functionCall(FunctionCall(identifier: Identifier(name: "bar"), arguments: [Expression.identifier(Identifier(name: "1")), Expression.identifier(Identifier(name: "2"))])), Expression.identifier(Identifier(name: "3")), Expression.binaryExpression(BinaryExpression(lhs: Expression.identifier(Identifier(name: "5")), op: .plus, rhs: Expression.functionCall(FunctionCall(identifier: Identifier(name: "bar"), arguments: [Expression.identifier(Identifier(name: "4")), Expression.identifier(Identifier(name: "6"))]))))])))]), FunctionDeclaration(modifiers: [], identifier: Identifier(name: "bar"), parameters: [Parameter(identifier: Identifier(name: "a"), type: Type(name: "Int")), Parameter(identifier: Identifier(name: "b"), type: Type(name: "Int"))], resultType: Optional(Type(name: "Int")), body: [Statement.returnStatement(ReturnStatement(expression: Expression.binaryExpression(BinaryExpression(lhs: Expression.identifier(Identifier(name: "a")), op: .plus, rhs: Expression.identifier(Identifier(name: "b"))))))])]))])

  func testFunctionCall() {
    test()
  }

}
