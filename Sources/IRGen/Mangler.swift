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

  /// Constructs the parameter name to indicate whether the given parameter is a memory reference.
  static func isMem(for parameter: String) -> String {
    return "\(parameter)$isMem"
  }
}

extension String {
  var mangled: String {
    return Mangler.mangleName(self)
  }
}
