//
//  String+Indentation.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/29/17.
//

extension String {
  func indented(by level: Int, andFirst: Bool = false) -> String {
    let lines = components(separatedBy: "\n")
    return ( andFirst ? String(repeating: " ", count: level) : "" ) + lines.joined(separator: "\n" + String(repeating: " ", count: level))
  }
}
