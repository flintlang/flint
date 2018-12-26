//
//  If.swift
//  YUL
//
//  Created by Aurel Bílý on 12/26/18.
//

// swiftlint:disable type_name
public struct If: CustomStringConvertible, Throwing {
// swiftlint:enable type_name
  public let expression: Expression
  public let block: Block

  public init(_ expression: Expression, _ block: Block) {
    self.expression = expression
    self.block = block
  }

  public var catchableSuccesses: [Expression] {
    return expression.catchableSuccesses
  }

  public var description: String {
    return "if \(expression.description) \(self.block)"
  }
}
