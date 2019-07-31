//
//  ForLoop.swift
//  YUL
//
//  Created by Aurel Bílý on 12/26/18.
//

public struct ForLoop: CustomStringConvertible {
  public let initialize: Block
  public let condition: Expression
  public let step: Block
  public let body: Block

  public init(_ initialize: Block, _ condition: Expression, _ step: Block, _ body: Block) {
    self.initialize = initialize
    self.condition = condition
    self.step = step
    self.body = body
  }

  public var description: String {
    var body_and_step: Block = body
    body_and_step.statements.append(contentsOf: step.statements)
    let initialize_statements = Statement.renderStatements(statements: initialize.statements)
    return """
    \(initialize_statements)
    while (\(condition)) \(body_and_step)
    """
  }
}
