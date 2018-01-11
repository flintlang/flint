//
//  MangledProperty.swift
//  AST
//
//  Created by Franklin Schrans on 1/11/18.
//

public struct MangledProperty: CustomStringConvertible {
  public var identifier: Identifier
  public var contractIdentifier: Identifier

  public init(inContract contract: Identifier, contractIdentifier: Identifier) {
    self.identifier = contract
    self.contractIdentifier = contractIdentifier
  }

  public var description: String {
    return "\(identifier.name)_\(contractIdentifier.name)"
  }
}

extension MangledProperty: Hashable {
  public static func ==(lhs: MangledProperty, rhs: MangledProperty) -> Bool {
    return lhs.identifier == rhs.identifier && lhs.contractIdentifier == rhs.contractIdentifier
  }

  public var hashValue: Int {
    return description.hashValue
  }
}
