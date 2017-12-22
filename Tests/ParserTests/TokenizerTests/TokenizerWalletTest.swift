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
      Token.contract, Token.identifier("Wallet"), Token.punctuation(Token.Punctuation.openBrace), Token.var, Token.identifier("owner"), Token.punctuation(Token.Punctuation.colon), Token.identifier("Address"), Token.var, Token.identifier("contents"), Token.punctuation(Token.Punctuation.colon), Token.identifier("Ether"), Token.punctuation(Token.Punctuation.closeBrace), Token.identifier("Wallet"), Token.punctuation(Token.Punctuation.doubleColon), Token.punctuation(Token.Punctuation.openBracket), Token.identifier("any"), Token.punctuation(Token.Punctuation.closeBracket), Token.punctuation(Token.Punctuation.openBrace), Token.public, Token.mutating, Token.func, Token.identifier("deposit"), Token.punctuation(Token.Punctuation.openBracket), Token.identifier("ether"), Token.punctuation(Token.Punctuation.colon), Token.identifier("Ether"), Token.punctuation(Token.Punctuation.closeBracket), Token.punctuation(Token.Punctuation.openBrace), Token.identifier("state"), Token.binaryOperator(Token.BinaryOperator.dot), Token.identifier("contents"), Token.binaryOperator(Token.BinaryOperator.equal), Token.identifier("state"), Token.binaryOperator(Token.BinaryOperator.dot), Token.identifier("contents"), Token.binaryOperator(Token.BinaryOperator.plus), Token.identifier("money"), Token.punctuation(Token.Punctuation.semicolon), Token.punctuation(Token.Punctuation.closeBrace), Token.punctuation(Token.Punctuation.closeBrace), Token.identifier("Wallet"), Token.punctuation(Token.Punctuation.doubleColon), Token.punctuation(Token.Punctuation.openBracket), Token.identifier("owner"), Token.punctuation(Token.Punctuation.closeBracket), Token.punctuation(Token.Punctuation.openBrace), Token.public, Token.mutating, Token.func, Token.identifier("withdraw"), Token.punctuation(Token.Punctuation.openBracket), Token.identifier("ether"), Token.punctuation(Token.Punctuation.colon), Token.identifier("Ether"), Token.punctuation(Token.Punctuation.closeBracket), Token.punctuation(Token.Punctuation.openBrace), Token.identifier("state"), Token.binaryOperator(Token.BinaryOperator.dot), Token.identifier("contents"), Token.binaryOperator(Token.BinaryOperator.equal), Token.identifier("state"), Token.binaryOperator(Token.BinaryOperator.dot), Token.identifier("contents"), Token.binaryOperator(Token.BinaryOperator.minus), Token.identifier("money"), Token.punctuation(Token.Punctuation.semicolon), Token.identifier("state"), Token.binaryOperator(Token.BinaryOperator.dot), Token.identifier("contents"), Token.binaryOperator(Token.BinaryOperator.equal), Token.identifier("state"), Token.binaryOperator(Token.BinaryOperator.dot), Token.identifier("contents"), Token.punctuation(Token.Punctuation.semicolon), Token.punctuation(Token.Punctuation.closeBrace), Token.public, Token.mutating, Token.func, Token.identifier("getContents"), Token.punctuation(Token.Punctuation.openBracket), Token.punctuation(Token.Punctuation.closeBracket), Token.punctuation(Token.Punctuation.arrow), Token.identifier("Ether"), Token.punctuation(Token.Punctuation.openBrace), Token.return, Token.identifier("state"), Token.binaryOperator(Token.BinaryOperator.dot), Token.identifier("contents"), Token.punctuation(Token.Punctuation.semicolon), Token.punctuation(Token.Punctuation.closeBrace), Token.punctuation(Token.Punctuation.closeBrace)
   ]

   func testWallet() {
      test()
   }
}
