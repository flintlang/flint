//
//  SemanticAnalyzerTest.swift
//  SemanticAnalyzerTests
//
//  Created by Franklin Schrans on 1/4/18.
//

import XCTest
import Parser
@testable import SemanticAnalyzer

protocol SemanticAnalyzerTest {
  var sourceCode: String { get }
}

extension SemanticAnalyzerTest {
  private var sourceFile: URL {
    let file = URL(fileURLWithPath: NSTemporaryDirectory() + UUID().uuidString)
    SourceFile(contents: sourceCode).write(to: file)
    return file
  }

  func analyze() throws {
    let tokens = Tokenizer(inputFile: sourceFile).tokenize()
    let (ast, context) = try! Parser(tokens: tokens).parse()
    try SemanticAnalyzer(ast: ast, context: context).analyze()
  }
}

fileprivate struct SourceFile {
  var contents: String

  func write(to location: URL) {
    try! contents.data(using: .utf8)?.write(to: location)
  }
}
