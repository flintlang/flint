//
//  TokenizerWalletTest.swift
//  TokenizerWalletTest
//
//  Created by Franklin Schrans on 12/19/17.
//

import XCTest
import Parser
import AST

class TokenizerWalletTest: XCTestCase, TokenizerTest {

  var sourceCode: String =
  """
  contract Wallet {
    var owner: Address
    var contents: Ether
  }

  Wallet :: (any) {
    public mutating func deposit(ether: Ether) {
      state.contents = state.contents + money;
    }
  }

  Wallet :: (owner) {
    public mutating func withdraw(ether: Ether) {
      state.contents = state.contents - money;
      state.contents = state.contents;
    }

    public mutating func getContents() -> Ether {
      return state.contents;
    }
  }
  """

  var expectedTokens: [Token] = [.contract, .identifier("Wallet"), .punctuation(.openBrace), .newline, .var, .identifier("owner"), .punctuation(.colon), .identifier("Address"), .newline, .var, .identifier("contents"), .punctuation(.colon), .identifier("Ether"), .newline, .punctuation(.closeBrace), .newline, .newline, .identifier("Wallet"), .punctuation(.doubleColon), .punctuation(.openBracket), .identifier("any"), .punctuation(.closeBracket), .punctuation(.openBrace), .newline, .public, .mutating, .func, .identifier("deposit"), .punctuation(.openBracket), .identifier("ether"), .punctuation(.colon), .identifier("Ether"), .punctuation(.closeBracket), .punctuation(.openBrace), .newline, .identifier("state"), .binaryOperator(.dot), .identifier("contents"), .binaryOperator(.equal), .identifier("state"), .binaryOperator(.dot), .identifier("contents"), .binaryOperator(.plus), .identifier("money"), .punctuation(.semicolon), .newline, .punctuation(.closeBrace), .newline, .punctuation(.closeBrace), .newline, .newline, .identifier("Wallet"), .punctuation(.doubleColon), .punctuation(.openBracket), .identifier("owner"), .punctuation(.closeBracket), .punctuation(.openBrace), .newline, .public, .mutating, .func, .identifier("withdraw"), .punctuation(.openBracket), .identifier("ether"), .punctuation(.colon), .identifier("Ether"), .punctuation(.closeBracket), .punctuation(.openBrace), .newline, .identifier("state"), .binaryOperator(.dot), .identifier("contents"), .binaryOperator(.equal), .identifier("state"), .binaryOperator(.dot), .identifier("contents"), .binaryOperator(.minus), .identifier("money"), .punctuation(.semicolon), .newline, .identifier("state"), .binaryOperator(.dot), .identifier("contents"), .binaryOperator(.equal), .identifier("state"), .binaryOperator(.dot), .identifier("contents"), .punctuation(.semicolon), .newline, .punctuation(.closeBrace), .newline, .newline, .public, .mutating, .func, .identifier("getContents"), .punctuation(.openBracket), .punctuation(.closeBracket), .punctuation(.arrow), .identifier("Ether"), .punctuation(.openBrace), .newline, .return, .identifier("state"), .binaryOperator(.dot), .identifier("contents"), .punctuation(.semicolon), .newline, .punctuation(.closeBrace), .newline, .punctuation(.closeBrace)]

  func testWallet() {
    test()
  }
}
