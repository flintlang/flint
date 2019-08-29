//
//  Module.swift
//  flintc
//
//  Created on 29/08/2019.
//

public struct ModuleImport: CustomStringConvertible, Throwing {
  public let name: String
  public let address: String

  public init(name: String, address: String) {
    self.name = name
    self.address = address
  }

  public var description: String {
    return "import \(address).\(name)"
  }

  public private(set) var catchableSuccesses: [Expression] = []
}
