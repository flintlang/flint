//
//  Mangler.swift
//  AST
//
//

import AST

public struct Mangler {
  static func mangleName(_ name: String) -> String {
    return "_\(name)"
  }

  public static func mangleFunctionName(_ name: String,
                                        parameterTypes: [RawType],
                                        enclosingType: String,
                                        isContract: Bool = false) -> String {
    let parameters = parameterTypes.map { $0.name }.joined(separator: "_")
    let dollar = parameters.isEmpty ? "" : "$"
    let type = isContract ? "" : enclosingType + "$"
    return "\(type)\(name)\(dollar)\(parameters)"
  }

  static func mangleInitializerName(_ enclosingType: String, parameterTypes: [RawType]) -> String {
    return mangleFunctionName("new", parameterTypes: parameterTypes, enclosingType: enclosingType)
  }
}

extension String {
  var mangled: String {
    return Mangler.mangleName(self)
  }
}
