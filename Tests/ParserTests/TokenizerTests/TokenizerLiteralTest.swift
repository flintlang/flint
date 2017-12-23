//
//  TokenizerLiteralTest.swift
//  ParserTests
//
//  Created by Franklin Schrans on 12/23/17.
//

import XCTest
@testable import Parser

class TokenizerLiteralTest: XCTestCase, TokenizerTest {
  var sourceCode: String =
  """
  Test :: (any) {
    func foo() -> Bool {
      var a = 2 + 4.564;
      var b = "hello" + " world";
      return false;
    }
  }
  """

  var expectedTokens: [Token] = [.identifier("Test"), .punctuation(.doubleColon), .punctuation(.openBracket), .identifier("any"), .punctuation(.closeBracket), .punctuation(.openBrace), .func, .identifier("foo"), .punctuation(.openBracket), .punctuation(.closeBracket), .punctuation(.arrow), .identifier("Bool"), .punctuation(.openBrace), .var, .identifier("a"), .binaryOperator(.equal), .decimalLiteral(.integer(2)), .binaryOperator(.plus), .decimalLiteral(.real(4, 564)), .punctuation(.semicolon), .var, .identifier("b"), .binaryOperator(.equal), .stringLiteral("hello"), .binaryOperator(.plus), .stringLiteral(" world"), .punctuation(.semicolon), .return, .booleanLiteral(.false), .punctuation(.semicolon), .punctuation(.closeBrace), .punctuation(.closeBrace)]


  func testLiteral() {
    test()
  }
}
