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
    XCTAssertTrue(RawType.externalType(.int112).canReinterpret(as: .basicType(.int)))
    XCTAssertTrue(RawType.externalType(.uint184).canReinterpret(as: .basicType(.int)))
    XCTAssertTrue(RawType.externalType(.string).canReinterpret(as: .basicType(.string)))
    XCTAssertTrue(RawType.externalType(.bool).canReinterpret(as: .basicType(.bool)))
    XCTAssertTrue(RawType.externalType(.address).canReinterpret(as: .basicType(.address)))

    XCTAssertFalse(RawType.externalType(.int256).canReinterpret(as: .basicType(.address)))
    XCTAssertFalse(RawType.externalType(.int64).canReinterpret(as: .basicType(.bool)))
  }

  func testBasicToSolidity() {
    XCTAssertTrue(RawType.basicType(.int).canReinterpret(as: .externalType(.int112)))
    XCTAssertTrue(RawType.basicType(.int).canReinterpret(as: .externalType(.int8)))
    XCTAssertTrue(RawType.basicType(.int).canReinterpret(as: .externalType(.uint192)))
    XCTAssertTrue(RawType.basicType(.int).canReinterpret(as: .externalType(.uint152)))

    XCTAssertTrue(RawType.basicType(.string).canReinterpret(as: .externalType(.string)))
    XCTAssertTrue(RawType.basicType(.bool).canReinterpret(as: .externalType(.bool)))
    XCTAssertTrue(RawType.basicType(.address).canReinterpret(as: .externalType(.address)))

    XCTAssertFalse(RawType.basicType(.event).canReinterpret(as: .externalType(.address)))
    XCTAssertFalse(RawType.basicType(.int).canReinterpret(as: .externalType(.address)))
    XCTAssertFalse(RawType.basicType(.int).canReinterpret(as: .externalType(.bool)))
  }

  func testSolidityToSolidity() {
    // Reinterpret indentically
    XCTAssertTrue(RawType.externalType(.int96).canReinterpret(as: .externalType(.int96)))
    // Reinterpret with unsigned
    XCTAssertTrue(RawType.externalType(.int96).canReinterpret(as: .externalType(.uint96)))
    // Reinterpret with more bits
    XCTAssertTrue(RawType.externalType(.int96).canReinterpret(as: .externalType(.int256)))
    // Reinterpret with fewer bits
    XCTAssertTrue(RawType.externalType(.int256).canReinterpret(as: .externalType(.int64)))
  }

  static var allTests = [
    ("testBasicToBasic", testBasicToBasic),
    ("testSolidityToBasic", testSolidityToBasic),
    ("testBasicToSolidity", testBasicToSolidity),
    ("testSolidityToSolidity", testSolidityToSolidity)
  ]
}
