import XCTest
@testable import Utils

final class UtilsTests: XCTestCase {
  func testOneLineNoIndentation() {
    // When
    let result = "foo".indented(by: 2)

    // Then
    XCTAssertEqual(result, "foo")
  }

  func testMultipleLinesNoFirstLineIndentation() {
    // When
    let result = """
    foo
    bar
    baz
    """.indented(by: 3)

    // Then
    XCTAssertEqual(result, """
    foo
       bar
       baz
    """)
  }

  func testOneLineWithIndentation() {
    // When
    let result = "foo".indented(by: 2, andFirst: true)

    // Then
    XCTAssertEqual(result, "  foo")
  }

  func testMultipleLinesWithFirstLineIndentation() {
    // When
    let result = """
    foo
    bar
    baz
    """.indented(by: 4, andFirst: true)

    // Then
    XCTAssertEqual(result, """
        foo
        bar
        baz
    """)
  }

  static var allTests = [
    ("testOneLineNoIndentation", testOneLineNoIndentation),
    ("testMultipleLinesNoFirstLineIndentation", testMultipleLinesNoFirstLineIndentation),
    ("testOneLineWithIndentation", testOneLineWithIndentation),
    ("testMultipleLinesWithFirstLineIndentation", testMultipleLinesWithFirstLineIndentation)
  ]
}
