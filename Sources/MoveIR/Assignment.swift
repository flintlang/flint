//
//  Assignment.swift
//  YUL
//
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
