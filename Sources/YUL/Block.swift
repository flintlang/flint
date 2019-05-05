//
//  Block.swift
//  YUL
//
//  Created by Aurel Bílý on 12/26/18.
//

import Utils

public struct Block: CustomStringConvertible {
  public var statements: [Statement]

  public init(_ statements: Statement...) {
    self.statements = statements
  }

  public var description: String {
    let statement_description = statements.map { $0.description }.joined(separator: "\n")

    return """
    {
      \(statement_description.indented(by: 2))
    }
    """
  }
}
