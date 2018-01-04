//
//  ParserTest.swift
//  ParserTests
//
//  Created by Franklin Schrans on 12/22/17.
//

import XCTest
import Parser
import Diagnostic

import AST

protocol ParserTest {
  var tokens: [Token] { get }
  var expectedAST: TopLevelModule { get }
}

extension ParserTest {
  func test() {
    XCTAssertEqual(Parser(tokens: tokens).parse().0!, expectedAST)
  }
}
