//
//  String+Indentation.swift
//  IULIABackend
//
//  Created by Franklin Schrans on 12/29/17.
//

extension String {
  func indented(by level: Int) -> String {
    let lines = components(separatedBy: "\n")
    return lines.joined(separator: "\n" + String(repeating: " ", count: level))
  }
}
