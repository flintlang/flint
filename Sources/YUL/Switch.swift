//
//  Switch.swift
//  YUL
//
//  Created by Aurel Bílý on 12/26/18.
//

public struct Switch: CustomStringConvertible, Throwing {
  public let expression: Expression
  public let cases: [(Literal, Block)]
  public let `default`: Block?

  public init(_ expression: Expression, cases: [(Literal, Block)], `default`: Block? = nil) {
    self.expression = expression
    self.cases = cases
    self.default = `default`
  }

  public init(_ expression: Expression, `default`: Block? = nil) {
    self.init(expression, cases: [], default: `default`)
  }

  public var catchableSuccesses: [Expression] {
    return expression.catchableSuccesses
  }

  public var description: String {
    let cases = self.cases.map { (lit, block) in
      return "case \(lit) \(block)"
    }.joined(separator: "\n")

    let `default`: String
    if let defaultContent = self.default {
      `default` = "\ndefault \(defaultContent)"
    } else {
      `default` = ""
    }

    return """
    switch \(self.expression)
    \(cases)\(`default`)
    """
  }
}
