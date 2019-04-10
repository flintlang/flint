//
//  String+Indentation.swift
//  Utils
//
//  Created by Aurel Bílý on 12/23/18.
//

import Foundation

public extension String {
  public func indented(by level: Int, andFirst: Bool = false) -> String {
    let lines = components(separatedBy: "\n")
    let spaces = String(repeating: " ", count: level)
    return (andFirst ? spaces : "") + lines.joined(separator: "\n" + spaces)
  }
}
