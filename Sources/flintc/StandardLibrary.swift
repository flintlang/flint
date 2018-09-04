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

  var runtimeFiles: [URL] {
    return flintFiles(at: url.appendingPathComponent("runtime"))
  }

  var coreFiles: [URL] {
    return flintFiles(at: url.appendingPathComponent("core"))
  }

  var globalFiles: [URL] {
    return flintFiles(at: url)
  }

  var files: [URL] {
    return runtimeFiles + coreFiles + globalFiles
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

  private func flintFiles(at url: URL) -> [URL] {
    return try! FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: []).filter { $0.pathExtension == "flint"}
  }
}
