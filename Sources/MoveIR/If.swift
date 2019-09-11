//
//  If.swift
//  YUL
//
//

// swiftlint:disable type_name
public struct If: CustomStringConvertible, Throwing {
// swiftlint:enable type_name
  public let expression: Expression
  public let block: Block
  public let elseBlock: Block?

  public init(_ expression: Expression, _ block: Block, _ elseBlock: Block?) {
    self.expression = expression
    self.block = block
    self.elseBlock = elseBlock
  }

  public var catchableSuccesses: [Expression] {
    return expression.catchableSuccesses
  }

  public var description: String {
    return "if (\(expression.description)) \(self.block) else \(self.elseBlock?.description ?? "{ }")"
  }
}
