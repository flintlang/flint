import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(ASTTests.allTests),
        testCase(TypeTests.allTests)
    ]
}
#endif
