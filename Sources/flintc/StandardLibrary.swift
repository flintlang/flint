//
//  StandardLibrary.swift
//  flintc
//
//  Created by Franklin Schrans on 5/12/18.
//

import Foundation

/// The Flint standard library.
struct StandardLibrary {
  /// Path to the stdlib directory.
  var url: URL

  func sourceCode() -> String {
    let files = try! FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
      .filter { $0.pathExtension == "flint" }

    return try! files.map(String.init(contentsOf:)).joined(separator: "\n\n")
  }
}
