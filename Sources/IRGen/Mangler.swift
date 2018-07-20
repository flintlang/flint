//
//  Mangler.swift
//  AST
//
//  Created by Franklin Schrans on 09/02/2018.
//

import AST

struct Mangler {
  static func mangleName(_ name: String) -> String {
    return "_\(name)"
  }

  static func mangleFunctionName(_ name: String, parameterTypes: [Type.RawType], enclosingType: String) -> String {
    let parameters = parameterTypes.map { $0.name }.joined(separator: "_")
    let dollar = parameters.isEmpty ? "" : "$"
    return "\(enclosingType)$\(name)\(dollar)\(parameters)"
  }

  static func mangleInitializerName(_ enclosingType: String, parameterTypes: [Type.RawType]) -> String {
    return mangleFunctionName("init", parameterTypes: parameterTypes, enclosingType: enclosingType)
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
