//
//  TokenizerTest.swift
//  ParserTests
//
//  Created by Franklin Schrans on 12/22/17.
//

import XCTest
import Parser

protocol TokenizerTest {
  var sourceCode: String { get }
  var expectedTokens: [Token] { get }
}

extension TokenizerTest {
  func test() {
    let file = URL(fileURLWithPath: NSTemporaryDirectory() + UUID().uuidString)
    SourceFile(contents: sourceCode).write(to: file)
    XCTAssertEqual(Tokenizer(inputFile: file).tokenize(), expectedTokens)
  }
}

fileprivate struct SourceFile {
  var contents: String
  
  func write(to location: URL) {
    try! contents.data(using: .utf8)?.write(to: location)
  }
}
