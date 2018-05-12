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

  func sourceCode() -> String {
    let files = try! FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
      .filter { $0.pathExtension == "flint" }

    return try! files.map(String.init(contentsOf:)).joined(separator: "\n\n")
  }

  static var `default`: StandardLibrary {
    guard let path = SymbolInfo(address: #dsohandle)?.filename else {
      fatalError("Unable to get SymbolInfo for \(#dsohandle)")
    }
    
    let url = path.deletingLastPathComponent().appendingPathComponent("stdlib")
    guard FileManager.default.fileExists(atPath: url.path) else {
      fatalError("Unable to find stdlib.")
    }

    return StandardLibrary(url: url)
  }
}
