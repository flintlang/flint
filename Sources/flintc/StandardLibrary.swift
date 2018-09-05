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
    var files = [URL]()
    let fileManager = FileManager.default
    let enumerator = fileManager.enumerator(at: url,
                                            includingPropertiesForKeys: nil,
                                            options: [], errorHandler: { (url, error) -> Bool in
                                              print("directoryEnumerator error at \(url): ", error)
                                              return true
    })!

    for case let fileURL as URL in enumerator {
      if fileURL.pathExtension == "flint" {
        files.append(fileURL)
      }
    }
    return files
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
