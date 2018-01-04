//
//  TokenizerTest.swift
//  ParserTests
//
//  Created by Franklin Schrans on 12/22/17.
//

import XCTest
import Parser
import AST

protocol TokenizerTest {
  var sourceCode: String { get }
  var expectedTokens: [Token] { get }
}

extension TokenizerTest {
  func test() {
    XCTAssertEqual(Tokenizer(sourceCode: sourceCode).tokenize(), expectedTokens)
  }
}
