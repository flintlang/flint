import XCTest
import AST
import Lexer
@testable import ASTPreprocessor

final class ASTPreprocessorTests: XCTestCase {

  let dotToken = Token(kind: .punctuation(.dot), sourceLocation: .DUMMY)
  private func namedIdentifier(_ name: String) -> Expression {
    return .identifier(Identifier(name: name, sourceLocation: .DUMMY))
  }

  private struct Fixture {
    let pass = ASTPreprocessor()
  }

  func testBinaryExpression_needsLeftRotation_leftRotationApplied() {
    // Given
    let f = Fixture()

    // a.(b.c)
    let originalTree =
      BinaryExpression(
        lhs: namedIdentifier("a"),
        op: dotToken,
        rhs: .binaryExpression(
          BinaryExpression(
            lhs: namedIdentifier("b"),
            op: dotToken,
            rhs: namedIdentifier("c"))))

    // (a.b).c
    let requiredTree =
      BinaryExpression(
        lhs: .binaryExpression(
          BinaryExpression(
            lhs: namedIdentifier("a"),
            op: dotToken,
            rhs: namedIdentifier("b"))),
        op: dotToken,
        rhs: namedIdentifier("c"))

    // When
    let result = f.pass.process(binaryExpression: originalTree, passContext: ASTPassContext())

    // Then
    XCTAssertTrue(result.element == requiredTree)
  }

  func testBinaryExpression_doesNotNeedLeftRotation_leftRotationNotApplied() {
    // Given
    let f = Fixture()

    // (a.b).c
    let tree =
      BinaryExpression(
        lhs: .binaryExpression(
          BinaryExpression(
            lhs: namedIdentifier("a"),
            op: dotToken,
            rhs: namedIdentifier("b"))),
        op: dotToken,
        rhs: namedIdentifier("c"))

    // When
    let result = f.pass.process(binaryExpression: tree, passContext: ASTPassContext())

    // Then
    XCTAssertTrue(result.element == tree)
  }

  func testBinaryExpression_childrenNotTreelike_leftRotationNotApplied() {
    // Given
    let f = Fixture()

    // a.(b.c)
    // This expression looks similar to those above, but this is an explicit bracketing that we need to allow
    let tree =
      BinaryExpression(
        lhs: namedIdentifier("a"),
        op: dotToken,
        rhs: .bracketedExpression(
          BracketedExpression(
            expression: .binaryExpression(
              BinaryExpression(
                lhs: namedIdentifier("b"),
                op: dotToken,
                rhs: namedIdentifier("c"))),
            openBracketToken: Token(kind: .punctuation(.openBracket), sourceLocation: .DUMMY),
            closeBracketToken: Token(kind: .punctuation(.closeBracket), sourceLocation: .DUMMY))))

    // When
    let result = f.pass.process(binaryExpression: tree, passContext: ASTPassContext())

    // Then
    XCTAssertTrue(result.element == tree)
  }

  func testBinaryExpression_notDotKind_leftRotationNotApplied() {
    // Given
    let f = Fixture()

    // a + b
    let tree =
      BinaryExpression(
        lhs: namedIdentifier("a"),
        op: Token(kind: .punctuation(.plus), sourceLocation: .DUMMY),
        rhs: namedIdentifier("b"))

    // When
    let result = f.pass.process(binaryExpression: tree, passContext: ASTPassContext())

    // Then
    XCTAssertTrue(result.element == tree)
  }

  func testBinaryExpression_rightChildNotDotKind_leftRotationNotApplied() {
    // Given
    let f = Fixture()

    // a.(b+c)
    let tree =
      BinaryExpression(
        lhs: namedIdentifier("a"),
        op: dotToken,
        rhs: .binaryExpression(
          BinaryExpression(
            lhs: namedIdentifier("b"),
            op: Token(kind: .punctuation(.plus), sourceLocation: .DUMMY),
            rhs: namedIdentifier("c"))))

    // When
    let result = f.pass.process(binaryExpression: tree, passContext: ASTPassContext())

    // Then
    XCTAssertTrue(result.element == tree)
  }

  static var allTests = [
    ("testBinaryExpression_needsLeftRotation_leftRotationApplied",
     testBinaryExpression_needsLeftRotation_leftRotationApplied),
    ("testBinaryExpression_doesNotNeedLeftRotation_leftRotationNotApplied",
     testBinaryExpression_doesNotNeedLeftRotation_leftRotationNotApplied),
    ("testBinaryExpression_childrenNotTreelike_leftRotationNotApplied",
     testBinaryExpression_childrenNotTreelike_leftRotationNotApplied),
    ("testBinaryExpression_notDotKind_leftRotationNotApplied",
     testBinaryExpression_notDotKind_leftRotationNotApplied),
    ("testBinaryExpression_rightChildNotDotKind_leftRotationNotApplied",
     testBinaryExpression_rightChildNotDotKind_leftRotationNotApplied)
  ]
}
