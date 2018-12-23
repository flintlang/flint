//
//  String+Indentation.swift
//  YUL
//
//  Created by Aurel Bílý on 23/12/18.
//

extension String {
  func indented(by level: Int, andFirst: Bool = false) -> String {
    let lines = components(separatedBy: "\n")
    let spaces = String(repeating: " ", count: level)
    return ( andFirst ? spaces : "" ) + lines.joined(separator: "\n" + spaces)
  }
}
