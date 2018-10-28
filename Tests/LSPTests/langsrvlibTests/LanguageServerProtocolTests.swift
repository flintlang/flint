// /*
//  * Copyright (c) Kiad Studios, LLC. All rights reserved.
//  * Licensed under the MIT License. See License in the project root for license information.
//  */

// import XCTest
// @testable import langsrvlib

// final class HeaderRejectionTests: XCTestCase {
//     func rejectHeader(_ header: String) {
//         do {
//             let _ = try parse(header: header)
//             XCTFail()
//         }
//         catch {
//             // pass
//         }
//     }

//     func testIncorrectHeaderRejection001() {
//         rejectHeader("Content-Length: 80")
//     }

//     func testIncorrectHeaderRejection002() {
//         rejectHeader("Content-Length: 80\r\n")
//     }

//     func testIncorrectHeaderRejection003() {
//         rejectHeader("\r\nContent-Length: 80\r\n\r\n")
//     }

//     func testIncorrectHeaderRejection004() {
//         rejectHeader("Content-Size: 80\r\n\r\n")
//     }

//     func testIncorrectHeaderRejection005() {
//         rejectHeader("Content-Length:80\n\n")
//     }

//     static var allTests = [
//         ("testIncorrectHeaderRejection001", testIncorrectHeaderRejection001),
//         ("testIncorrectHeaderRejection002", testIncorrectHeaderRejection002),
//         ("testIncorrectHeaderRejection003", testIncorrectHeaderRejection003),
//         ("testIncorrectHeaderRejection004", testIncorrectHeaderRejection004),
//         ("testIncorrectHeaderRejection005", testIncorrectHeaderRejection005),
//     ]
// }

// final class HeaderAcceptanceTests: XCTestCase {
//     func acceptHeader(_ header: String) {
//         do {
//             let _ = try parse(header: header)
//         }
//         catch {
//             XCTFail("\(error)")
//         }
//     }

//     func testValidHeader001() {
//         acceptHeader("Content-Length: 80\n\n")
//     }

//     func testValidHeader002() {
//         acceptHeader("Content-Length: 80\r\n\r\n")
//     }

//     func testValidHeader003() {
//         acceptHeader("Content-Length: 80\r\r\n")
//     }

//     static var allTests = [
//         ("testValidHeader001", testValidHeader001),
//         ("testValidHeader002", testValidHeader002),
//         ("testValidHeader003", testValidHeader003),
//     ]
// }