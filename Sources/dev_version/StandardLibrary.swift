//
//  StandardLibrary.swift
//  flintc
//
//  Created by Franklin Schrans on 5/12/18.
//

import Foundation
import Symbolic

/// The Flint standard library.
struct StandardLibrary {
  /// Path to the stdlib directory.
  var url: URL

  var files: [URL] {
    // swiftlint:disable force_try
    return try! FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
      .filter { $0.pathExtension == "flint" }
    // swiftlint:enable force_try
  }

  static var `default`: StandardLibrary {
    guard let path = SymbolInfo(address: #dsohandle)?.filename else {
      fatalError("Unable to get SymbolInfo for \(#dsohandle)")
    }

    //let url = path.deletingLastPathComponent().appendingPathComponent("stdlib")
    let url = URL(string: "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/stdlib")!
    guard FileManager.default.fileExists(atPath: url.path) else {
      fatalError("Unable to find stdlib.")
    }

    return StandardLibrary(url: url)
  }
}
