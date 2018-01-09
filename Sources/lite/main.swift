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

func run() -> Int32 {
  let allPassed = try! runLite(substitutions: [("flintc", "\(flintcExecutableLocation.path)"), ("FileCheck", "\"\(fileCheckExecutableLocation.path)\"")],
                              pathExtensions: ["flint"],
                              testDirPath: nil,
                              testLinePrefix: "//",
                              parallelismLevel: .automatic)
  return allPassed ? EXIT_SUCCESS : EXIT_FAILURE
}

exit(run())
