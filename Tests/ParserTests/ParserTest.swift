//
//  ParserTest.swift
//  ParserTests
//
//  Created by Franklin Schrans on 12/22/17.
//

import XCTest
import Parser

import AST

protocol ParserTest {
  var tokens: [Token] { get }
  var expectedAST: TopLevelModule { get }
}

extension ParserTest {
  func test() {
    XCTAssertEqual(try Parser(tokens: tokens).parse(), expectedAST)
  }
}
