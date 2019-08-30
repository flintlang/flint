//
//  StandardLibrary.swift
//  flintc
//
//  Created by Franklin Schrans on 5/12/18.
//

import Foundation
import Symbolic
import Utils

/// The Flint standard library.
public struct StandardLibrary {
  /// Path to the stdlib directory.
  public var url: URL

  public var files: [URL] {
    // swiftlint:disable force_try
    return try! FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
      .filter { $0.pathExtension == "flint" }
    // swiftlint:enable force_try
  }

  public static var `default`: StandardLibrary {
    return StandardLibrary.from(name: "common")
  }

  public static func from(name: String) -> StandardLibrary {
    return StandardLibrary(url: Path.getFullUrl(path: "stdlib/\(name)"))
  }

  public static func from(target: CompilerTarget) -> StandardLibrary {
    switch target {
    case .evm: return StandardLibrary.from(name: "evm")
    case .move: return StandardLibrary.from(name: "common")
    default: return StandardLibrary.default
    }
  }
}
