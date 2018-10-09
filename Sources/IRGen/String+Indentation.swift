//
//  String+Indentation.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/29/17.
//

extension String {
  func indented(by level: Int, andFirst: Bool = false) -> String {
    let lines = components(separatedBy: "\n")
    let spaces = String(repeating: " ", count: level)
    return ( andFirst ? spaces : "" ) + lines.joined(separator: "\n" + spaces)
  }
}
