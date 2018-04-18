//
//  main.swift
//  lite
//
//  Created by Franklin Schrans on 12/19/17.
//

import Foundation
import LiteSupport
import Rainbow
import Symbolic

#if os(Linux)
  import Glibc
#endif

/// Finds the named executable relative to the location of the `lite`
/// executable.
// Thank you Harlan and Robert! (https://github.com/silt-lang/silt/blob/master/Sources/lite/SiltInvocation.swift)
func findAdjacentBinary(_ name: String) -> URL? {
  guard let path = SymbolInfo(address: #dsohandle)?.filename else { return nil }
  let siltURL = path.deletingLastPathComponent()
    .appendingPathComponent(name)
  guard FileManager.default.fileExists(atPath: siltURL.path) else { return nil }
  return siltURL
}

var flintcExecutableLocation: URL {
  return findAdjacentBinary("flintc")!
}

var fileCheckExecutableLocation: URL {
  return findAdjacentBinary("file-check")!
}

func runParserTests() -> Bool {
  let allPassed = try! runLite(substitutions: [("flintc", "\(flintcExecutableLocation.path)"), ("FileCheck", "\"\(fileCheckExecutableLocation.path)\"")],
                              pathExtensions: ["flint"],
                              testDirPath: "Tests/ParserTests",
                              testLinePrefix: "//",
                              parallelismLevel: .automatic)
  return allPassed
}

func runSemanticTests() -> Bool {
  let allPassed = try! runLite(substitutions: [("flintc", "\(flintcExecutableLocation.path)")],
                               pathExtensions: ["flint"],
                               testDirPath: "Tests/SemanticTests",
                               testLinePrefix: "//",
                               parallelismLevel: .automatic)
  return allPassed
}

func runBehaviorTests() -> Bool {
  let allPassed = try! runLite(substitutions: [("flintc", "\(flintcExecutableLocation.path)")],
                               pathExtensions: ["js"],
                               testDirPath: "Tests/BehaviorTests",
                               testLinePrefix: "//",
                               parallelismLevel: .none)
  return allPassed
}

func run() -> Int32 {
  return runParserTests() && runSemanticTests() && runBehaviorTests() ? EXIT_SUCCESS : EXIT_FAILURE
}

exit(run())
