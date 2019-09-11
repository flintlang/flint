//
//  Block.swift
//  YUL
//
//

import Utils

public struct Block: CustomStringConvertible {
  public var statements: [Statement]

  public init(_ statements: Statement...) {
    self.statements = statements
  }

  public var description: String {
    let statement_description = Statement.renderStatements(statements: self.statements)
    return """
    {
      \(statement_description.indented(by: 2))
    }
    """
  }
}
