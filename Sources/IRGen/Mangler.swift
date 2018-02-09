//
//  Mangler.swift
//  IRGen
//
//  Created by Schrans, Franklin C P T T on 09/02/2018.
//

struct Mangler {
  static func mangledName(_ name: String, enclosingType: String) -> String {
    return "\(enclosingType)_\(name)"
  }
}
