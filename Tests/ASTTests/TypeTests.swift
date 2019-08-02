//
//  TypeTests.swift
//  ASTTests
//
//  Created by Nik on 15/11/2018.
//

import XCTest
@testable import AST

final class TypeTests: XCTestCase {

  func testBasicToBasic() {
    XCTAssertTrue(RawType.basicType(.int).canReinterpret(as: .basicType(.int)))
    XCTAssertTrue(RawType.basicType(.string).canReinterpret(as: .basicType(.string)))

    XCTAssertFalse(RawType.basicType(.int).canReinterpret(as: .basicType(.string)))
    XCTAssertFalse(RawType.basicType(.string).canReinterpret(as: .basicType(.event)))
    XCTAssertFalse(RawType.basicType(.int).canReinterpret(as: .basicType(.bool)))
    XCTAssertFalse(RawType.basicType(.int).canReinterpret(as: .basicType(.address)))
  }

  func testSolidityToBasic() {
    XCTAssertTrue(RawType.solidityType(.int112).canReinterpret(as: .basicType(.int)))
    XCTAssertTrue(RawType.solidityType(.uint184).canReinterpret(as: .basicType(.int)))
    XCTAssertTrue(RawType.solidityType(.string).canReinterpret(as: .basicType(.string)))
    XCTAssertTrue(RawType.solidityType(.bool).canReinterpret(as: .basicType(.bool)))
    XCTAssertTrue(RawType.solidityType(.address).canReinterpret(as: .basicType(.address)))

    XCTAssertFalse(RawType.solidityType(.int256).canReinterpret(as: .basicType(.address)))
    XCTAssertFalse(RawType.solidityType(.int64).canReinterpret(as: .basicType(.bool)))
  }

  func testBasicToSolidity() {
    XCTAssertTrue(RawType.basicType(.int).canReinterpret(as: .solidityType(.int112)))
    XCTAssertTrue(RawType.basicType(.int).canReinterpret(as: .solidityType(.int8)))
    XCTAssertTrue(RawType.basicType(.int).canReinterpret(as: .solidityType(.uint192)))
    XCTAssertTrue(RawType.basicType(.int).canReinterpret(as: .solidityType(.uint152)))

    XCTAssertTrue(RawType.basicType(.string).canReinterpret(as: .solidityType(.string)))
    XCTAssertTrue(RawType.basicType(.bool).canReinterpret(as: .solidityType(.bool)))
    XCTAssertTrue(RawType.basicType(.address).canReinterpret(as: .solidityType(.address)))

    XCTAssertFalse(RawType.basicType(.event).canReinterpret(as: .solidityType(.address)))
    XCTAssertFalse(RawType.basicType(.int).canReinterpret(as: .solidityType(.address)))
    XCTAssertFalse(RawType.basicType(.int).canReinterpret(as: .solidityType(.bool)))
  }

  func testSolidityToSolidity() {
    // Reinterpret indentically
    XCTAssertTrue(RawType.solidityType(.int96).canReinterpret(as: .solidityType(.int96)))
    // Reinterpret with unsigned
    XCTAssertTrue(RawType.solidityType(.int96).canReinterpret(as: .solidityType(.uint96)))
    // Reinterpret with more bits
    XCTAssertTrue(RawType.solidityType(.int96).canReinterpret(as: .solidityType(.int256)))
    // Reinterpret with fewer bits
    XCTAssertTrue(RawType.solidityType(.int256).canReinterpret(as: .solidityType(.int64)))
  }

  static var allTests = [
    ("testBasicToBasic", testBasicToBasic),
    ("testSolidityToBasic", testSolidityToBasic),
    ("testBasicToSolidity", testBasicToSolidity),
    ("testSolidityToSolidity", testSolidityToSolidity)
  ]
}
