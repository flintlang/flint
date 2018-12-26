import XCTest

import SourceTests
import CompilerTests
import DiagnosticTests
import LexerTests
import ASTTests
import ASTPreprocessorTests
import ParserTests
import SemanticAnalyzerTests
import TypeCheckerTests
import OptimizerTests
import IRGenTests
import ABITests
import UtilsTests

var tests = [XCTestCaseEntry]()
tests += SourceTests.allTests()
tests += CompilerTests.allTests()
tests += DiagnosticTests.allTests()
tests += LexerTests.allTests()
tests += ASTTests.allTests()
tests += ASTPreprocessorTests.allTests()
tests += ParserTests.allTests()
tests += SemanticAnalyzerTests.allTests()
tests += TypeCheckerTests.allTests()
tests += OptimizerTests.allTests()
tests += IRGenTests.allTests()
tests += ABITests.allTests()
tests += UtilsTests.allTests()
XCTMain(tests)
