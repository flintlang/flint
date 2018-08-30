//
//  FunctionArgument.swift
//  AST
//
//  Created by Hails, Daniel J R on 29/08/2018.
//
import Source
import Lexer

// An argument to a function call
public struct FunctionArgument: ASTNode {
  public var identifier: Identifier?
  public var expression: Expression

  public init(identifier: Identifier?, expression: Expression) {
    self.identifier = identifier
    self.expression = expression
  }

  public init(_ expression: Expression) {
    self.identifier = nil
    self.expression = expression
  }

  // MARK: - ASTNode
  public var sourceLocation: SourceLocation {
    return expression.sourceLocation
  }

  public var description: String {
    if let id = identifier {
      return "\(id): \(expression)"
    }
    return "\(expression)"
  }
}
