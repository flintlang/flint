//
//  Assignment.swift
//  YUL
//
//  Created by Aurel Bílý on 12/26/18.
//

public struct Assignment: CustomStringConvertible, Throwing {
  public let identifier: Identifier
  public let expression: Expression

  public init(_ identifier: Identifier, _ expression: Expression) {
    self.identifier = identifier
    self.expression = expression
  }

  public var catchableSuccesses: [Expression] {
    return expression.catchableSuccesses
  }

  public var description: String {
    return "\(self.identifier) = \(self.expression)"
  }
}
