//
//  TokenizerTests.swift
//  ParserTests
//
//  Created by Franklin Schrans on 12/19/17.
//

import XCTest
import Parser

class TokenizerTests: XCTestCase {

    func testWallet() {
      let inputFile = URL(fileURLWithPath: NSTemporaryDirectory() + NSUUID().uuidString)
      SourceFile(contents: """
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
        }
      
        public mutating func getContents() -> Ether {
          return state.contents;
        }
      }
      """).write(to: inputFile)

      let tokenizer = Tokenizer(inputFile: inputFile)

      let expectedTokens: [Token] = [.contract, .identifier("Wallet"), .punctuation(.openBrace), .var, .identifier("owner"), .punctuation(.colon),
            .identifier("Address"), .var, .identifier("contents"), .punctuation(.colon), .identifier("Ether"),
            .punctuation(.closeBrace), .identifier("Wallet"), .punctuation(.doubleColon), .punctuation(.openBracket),
            .identifier("any"), .punctuation(.closeBracket), .punctuation(.openBrace), .public, .mutating, .func,
            .identifier("deposit"), .punctuation(.openBracket), .identifier("ether"), .punctuation(.colon), .identifier("Ether"),
            .punctuation(.closeBracket), .punctuation(.openBrace), .identifier("state"), .binaryOperator(.dot),
            .identifier("contents"), .binaryOperator(.equal), .identifier("state"), .binaryOperator(.dot),
            .identifier("contents"), .binaryOperator(.plus), .identifier("money"), .punctuation(.semicolon), .punctuation(.closeBrace),
            .punctuation(.closeBrace), .identifier("Wallet"), .punctuation(.doubleColon), .punctuation(.openBracket),
            .identifier("owner"), .punctuation(.closeBracket), .punctuation(.openBrace), .public, .mutating, .func,
            .identifier("withdraw"), .punctuation(.openBracket), .identifier("ether"), .punctuation(.colon), .identifier("Ether"),
            .punctuation(.closeBracket), .punctuation(.openBrace), .identifier("state"), .binaryOperator(.dot),
            .identifier("contents"), .binaryOperator(.equal), .identifier("state"), .binaryOperator(.dot),
            .identifier("contents"), .binaryOperator(.minus), .identifier("money"), .punctuation(.semicolon), .punctuation(.closeBrace),
            .public, .mutating, .func, .identifier("getContents"), .punctuation(.openBracket), .punctuation(.closeBracket),
            .punctuation(.arrow), .identifier("Ether"), .punctuation(.openBrace), .return, .identifier("state"),
            .binaryOperator(.dot), .identifier("contents"), .punctuation(.semicolon), .punctuation(.closeBrace), .punctuation(.closeBrace)]

      XCTAssertEqual(tokenizer.tokenize(), expectedTokens)
    }
}
