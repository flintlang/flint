//
//  TokenizerTests.swift
//  ParserTests
//
//  Created by Franklin Schrans on 12/19/17.
//

import XCTest
import Parser

class LexerTests: XCTestCase {

    func testWallet() {
      let inputFile = Bundle(for: type(of: self)).url(forResource: "wallet", withExtension: ".ethl")!
      let tokenizer = Tokenizer(inputFile: inputFile)

      let expectedTokens: [Token] = [.contract, .identifier("Wallet"), .marker(.openBrace), .var, .identifier("owner"), .marker(.colon),
            .identifier("Address"), .var, .identifier("contents"), .marker(.colon), .identifier("Ether"),
            .marker(.closeBrace), .identifier("Wallet"), .marker(.doubleColon), .marker(.openBracket),
            .identifier("any"), .marker(.closeBracket), .marker(.openBrace), .public, .mutating, .func,
            .identifier("deposit"), .marker(.openBracket), .identifier("Ether"), .identifier("ether"),
            .marker(.closeBracket), .marker(.openBrace), .identifier("state"), .binaryOperator(.dot),
            .identifier("contents"), .binaryOperator(.equal), .identifier("state"), .binaryOperator(.dot),
            .identifier("contents"), .binaryOperator(.plus), .identifier("money"), .marker(.closeBrace),
            .marker(.closeBrace), .identifier("Wallet"), .marker(.doubleColon), .marker(.openBracket),
            .identifier("owner"), .marker(.closeBracket), .marker(.openBrace), .public, .mutating, .func,
            .identifier("withdraw"), .marker(.openBracket), .identifier("Ether"), .identifier("ether"),
            .marker(.closeBracket), .marker(.openBrace), .identifier("state"), .binaryOperator(.dot),
            .identifier("contents"), .binaryOperator(.equal), .identifier("state"), .binaryOperator(.dot),
            .identifier("contents"), .binaryOperator(.minus), .identifier("money"), .marker(.closeBrace),
            .public, .mutating, .func, .identifier("getContents"), .marker(.openBracket), .marker(.closeBracket),
            .marker(.arrow), .identifier("Ether"), .marker(.openBrace), .return, .identifier("state"),
            .binaryOperator(.dot), .identifier("contents"), .marker(.closeBrace), .marker(.closeBrace)]

      XCTAssertEqual(tokenizer.tokenize(), expectedTokens)
    }
}
