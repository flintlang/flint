//
//  Array+Parameter.swift
//  AST
//
//  Created by Niklas Vangerow on 26/10/2018.
//

import Foundation

public extension Array where Element == Parameter {
  var identifierNames: [String] {
    return map { $0.identifier.name }
  }

  var rawTypes: [RawType] {
    return map { $0.type.rawType }
  }
}
