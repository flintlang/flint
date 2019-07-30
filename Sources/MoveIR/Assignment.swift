//
//  Assignment.swift
//  YUL
//
//  Created by Aurel Bílý on 12/26/18.
//

public struct Assignment: CustomStringConvertible, Throwing {
  public let identifiers: [Identifier]
  public let expression: Expression

  public init(_ identifiers: [Identifier], _ expression: Expression) {
    self.identifiers = identifiers
    self.expression = expression
  }

  public var catchableSuccesses: [Expression] {
    return expression.catchableSuccesses
  }

  public var description: String {
    let lhs = self.identifiers.joined(separator: ", ")
    print(lhs)
    return "\(lhs) := \(self.expression)"
  }
}
