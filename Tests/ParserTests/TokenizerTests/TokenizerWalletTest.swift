//
//  TokenizerWalletTest.swift
//  TokenizerWalletTest
//
//  Created by Franklin Schrans on 12/19/17.
//

import XCTest
import Parser

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
    
    var expectedTokens: [Token] = [
        .contract, .identifier("Wallet"), .punctuation(.openBrace), .var, .identifier("owner"), .punctuation(.colon), .identifier("Address"), .var, .identifier("contents"), .punctuation(.colon), .identifier("Ether"), .punctuation(.closeBrace), .identifier("Wallet"), .punctuation(.doubleColon), .punctuation(.openBracket), .identifier("any"), .punctuation(.closeBracket), .punctuation(.openBrace), .public, .mutating, .func, .identifier("deposit"), .punctuation(.openBracket), .identifier("ether"), .punctuation(.colon), .identifier("Ether"), .punctuation(.closeBracket), .punctuation(.openBrace), .identifier("state"), .binaryOperator(.dot), .identifier("contents"), .binaryOperator(.equal), .identifier("state"), .binaryOperator(.dot), .identifier("contents"), .binaryOperator(.plus), .identifier("money"), .punctuation(.semicolon), .punctuation(.closeBrace), .punctuation(.closeBrace), .identifier("Wallet"), .punctuation(.doubleColon), .punctuation(.openBracket), .identifier("owner"), .punctuation(.closeBracket), .punctuation(.openBrace), .public, .mutating, .func, .identifier("withdraw"), .punctuation(.openBracket), .identifier("ether"), .punctuation(.colon), .identifier("Ether"), .punctuation(.closeBracket), .punctuation(.openBrace), .identifier("state"), .binaryOperator(.dot), .identifier("contents"), .binaryOperator(.equal), .identifier("state"), .binaryOperator(.dot), .identifier("contents"), .binaryOperator(.minus), .identifier("money"), .punctuation(.semicolon), .identifier("state"), .binaryOperator(.dot), .identifier("contents"), .binaryOperator(.equal), .identifier("state"), .binaryOperator(.dot), .identifier("contents"), .punctuation(.semicolon), .punctuation(.closeBrace), .public, .mutating, .func, .identifier("getContents"), .punctuation(.openBracket), .punctuation(.closeBracket), .punctuation(.arrow), .identifier("Ether"), .punctuation(.openBrace), .return, .identifier("state"), .binaryOperator(.dot), .identifier("contents"), .punctuation(.semicolon), .punctuation(.closeBrace), .punctuation(.closeBrace)
    ]
    
    func testWallet() {
        test()
    }
}
