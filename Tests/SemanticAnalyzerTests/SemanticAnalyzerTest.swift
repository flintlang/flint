//
//  SemanticAnalyzerTest.swift
//  SemanticAnalyzerTests
//
//  Created by Franklin Schrans on 1/4/18.
//

import XCTest
import Parser
@testable import SemanticAnalyzer
import Diagnostic

protocol SemanticAnalyzerTest {
  var sourceCode: String { get }
}

extension SemanticAnalyzerTest {
  func analyze() -> [Diagnostic] {
    let tokens = Tokenizer(sourceCode: sourceCode).tokenize()
    let (ast, context, _) = Parser(tokens: tokens).parse()
    let analyzer = SemanticAnalyzer(ast: ast!, context: context)
    analyzer.visit(ast!)
    return analyzer.diagnostics
  }
}

fileprivate struct SourceFile {
  var contents: String

  func write(to location: URL) {
    try! contents.data(using: .utf8)?.write(to: location)
  }
}
