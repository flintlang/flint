//
//  Mangler.swift
//  IRGen
//
//  Created by Franklin Schrans on 09/02/2018.
//

struct Mangler {
  static func mangleName(_ name: String, enclosingType: String? = nil) -> String {
    return "\(enclosingType ?? "")_\(name)"
  }

  static func mangleInitializer(enclosingType: String) -> String {
    return "\(enclosingType)_init"
  }
}
