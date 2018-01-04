//
//  InvalidContractBehaviorDeclarationTest.swift
//  SemanticAnalyzerTests
//
//  Created by Franklin Schrans on 1/4/18.
//

import XCTest
@testable import SemanticAnalyzer
import Diagnostic

class InvalidContractBehaviorDeclarationTest: XCTestCase, SemanticAnalyzerTest {
  var sourceCode: String =
  """
  Test :: (any) {}
  """

  func test() {
    let diagnostics = analyze()
    XCTAssertEqual(diagnostics.count, 1)
  }

}
