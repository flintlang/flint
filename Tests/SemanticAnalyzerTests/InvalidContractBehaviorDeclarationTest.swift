//
//  InvalidContractBehaviorDeclarationTest.swift
//  SemanticAnalyzerTests
//
//  Created by Franklin Schrans on 1/4/18.
//

import XCTest
@testable import SemanticAnalyzer

class InvalidContractBehaviorDeclarationTest: XCTestCase, SemanticAnalyzerTest {
  var sourceCode: String =
  """
  Test :: (any) {}
  """

  func test() {
    do {
      try analyze()
    } catch SemanticError.contractBehaviorDeclarationNoMatchingContract(_) {
      return
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTFail()
  }

}
