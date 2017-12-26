//
//  FunctionCallTest.swift
//  ParserTests
//
//  Created by Franklin Schrans on 12/22/17.
//

import XCTest
@testable import Parser
import AST

// Test :: (any) {
//   func foo(a: Int) -> Int {
//     foo(bar(1, 2), 3, 5 + bar(4, 6)); return 2;
//   }
// 
//   func bar(a: Int, b: Int) -> Int {
//     return a + b;
//   }
// }

class FunctionCallTest: XCTestCase, ParserTest {
  var tokens: [Token] = [.identifier("Test"), .punctuation(.doubleColon), .punctuation(.openBracket), .identifier("any"), .punctuation(.closeBracket), .              punctuation(.openBrace), .newline, .func, .identifier("foo"), .punctuation(.openBracket), .identifier("a"), .punctuation(.colon), .          identifier("Int"), .punctuation(.closeBracket), .punctuation(.arrow), .identifier("Int"), .punctuation(.openBrace), .newline, .                      identifier("foo"), .punctuation(.openBracket), .identifier("bar"), .punctuation(.openBracket), .literal(.decimal(.integer(1))), .punctuation(.    comma), .literal(.decimal(.integer(2))), .punctuation(.closeBracket), .punctuation(.comma), .literal(.decimal(.integer(3))), .punctuation(.          comma), .literal(.decimal(.integer(5))), .binaryOperator(.plus), .identifier("bar"), .punctuation(.openBracket), .literal(.decimal(.            integer(4))), .punctuation(.comma), .literal(.decimal(.integer(6))), .punctuation(.closeBracket), .punctuation(.closeBracket), .punctuation(.       semicolon), .newline, .newline, .return, .literal(.decimal(.integer(2))), .newline, .punctuation(.closeBrace), .newline, .newline, .      func, .identifier("bar"), .punctuation(.openBracket), .identifier("a"), .punctuation(.colon), .identifier("Int"), .punctuation(.comma), .              identifier("b"), .punctuation(.colon), .identifier("Int"), .punctuation(.closeBracket), .punctuation(.arrow), .identifier("Int"), .punctuation(.       openBrace), .newline, .return, .identifier("a"), .binaryOperator(.plus), .identifier("b"), .newline, .punctuation(.closeBrace), .newline, .             punctuation(.closeBrace), .newline, .newline]

  var expectedAST: TopLevelModule =
TopLevelModule(declarations: [TopLevelDeclaration.contractBehaviorDeclaration(ContractBehaviorDeclaration(contractIdentifier: Identifier(name: "Test"), callerCapabilities: [CallerCapability(name: "any")], functionDeclarations: [FunctionDeclaration(modifiers: [], identifier: Identifier(name: "foo"), parameters: [Parameter(identifier: Identifier(name: "a"), type: Type(name: "Int"))], resultType: Optional(Type(name: "Int")), body: [Statement.expression(Expression.functionCall(FunctionCall(identifier: Identifier(name: "foo"), arguments: [Expression.functionCall(FunctionCall(identifier: Identifier(name: "bar"), arguments: [Expression.literal(.decimal(.integer(1))), Expression.literal(.decimal(.integer(2)))])), Expression.literal(.decimal(.integer(3))), Expression.binaryExpression(BinaryExpression(lhs: Expression.literal(.decimal(.integer(5))), op: .plus, rhs: Expression.functionCall(FunctionCall(identifier: Identifier(name: "bar"), arguments: [Expression.literal(.decimal(.integer(4))), Expression.literal(.decimal(.integer(6)))]))))]))), Statement.returnStatement(ReturnStatement(expression: Expression.literal(.decimal(.integer(2)))))]), FunctionDeclaration(modifiers: [], identifier: Identifier(name: "bar"), parameters: [Parameter(identifier: Identifier(name: "a"), type: Type(name: "Int")), Parameter(identifier: Identifier(name: "b"), type: Type(name: "Int"))], resultType: Optional(Type(name: "Int")), body: [Statement.returnStatement(ReturnStatement(expression: Expression.binaryExpression(BinaryExpression(lhs: Expression.identifier(Identifier(name: "a")), op: .plus, rhs: Expression.identifier(Identifier(name: "b"))))))])]))])

  func testFunctionCall() {
    test()
  }

}
