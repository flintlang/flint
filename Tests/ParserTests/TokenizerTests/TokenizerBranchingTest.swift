//
//  TokenizerBranchingTest.swift
//  ParserTests
//
//  Created by Franklin Schrans on 12/25/17.
//

import XCTest
import Parser

class TokenizerBranchingTest: XCTestCase, TokenizerTest {
  var sourceCode: String =
  """
  contract Wallet {
    var owner: Address
    var contents: Ether
  }

  Wallet :: (any) {
    func factorial(n: Int) -> Int {
      if (n < 2) { return 0 }

      return n * factorial(n - 1)
    }

    func foo() {
      if true { print("error"); return; }
    }
  }
  """

  var expectedTokens: [Token] =
    [.contract, .identifier("Wallet"), .punctuation(.openBrace), .newline, .var, .identifier("owner"), .punctuation(.colon), .identifier("Address"), .newline, .var, .identifier("contents"), .punctuation(.colon), .identifier("Ether"), .newline, .punctuation(.closeBrace), .newline, .newline, .identifier("Wallet"), .punctuation(.doubleColon), .punctuation(.openBracket), .identifier("any"), .punctuation(.closeBracket), .punctuation(.openBrace), .newline, .func, .identifier("factorial"), .punctuation(.openBracket), .identifier("n"), .punctuation(.colon), .identifier("Int"), .punctuation(.closeBracket), .punctuation(.arrow), .identifier("Int"), .punctuation(.openBrace), .newline, .if, .punctuation(.openBracket), .identifier("n"), .binaryOperator(.lessThan), .literal(.decimal(.integer(2))), .punctuation(.closeBracket), .punctuation(.openBrace), .return, .literal(.decimal(.integer(0))), .punctuation(.closeBrace), .newline, .newline, .return, .identifier("n"), .binaryOperator(.times), .identifier("factorial"), .punctuation(.openBracket), .identifier("n"), .binaryOperator(.minus), .literal(.decimal(.integer(1))), .punctuation(.closeBracket), .newline, .punctuation(.closeBrace), .newline, .newline, .func, .identifier("foo"), .punctuation(.openBracket), .punctuation(.closeBracket), .punctuation(.openBrace), .newline, .if, .literal(.boolean(.true)), .punctuation(.openBrace), .identifier("print"), .punctuation(.openBracket), .literal(.string("error")), .punctuation(.closeBracket), .punctuation(.semicolon), .return, .punctuation(.semicolon), .punctuation(.closeBrace), .newline, .punctuation(.closeBrace), .newline, .punctuation(.closeBrace)]

  func testBranching() {
    test()
  }
}
