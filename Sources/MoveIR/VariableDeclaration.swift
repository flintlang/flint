//
//  VariableDeclaration.swift
//  YUL
//
//  Created by Aurel Bílý on 12/26/18.
//

public struct VariableDeclaration: CustomStringConvertible, Throwing {
  public let declaration: TypedIdentifier
  public let expression: Expression?

  public init(_ declaration: TypedIdentifier, _ expression: Expression?) {
    self.declaration = declaration
    self.expression = expression
  }

  public var catchableSuccesses: [Expression] {
    return expression?.catchableSuccesses ?? []
  }

  public var description: String {
    return "let \(render(typedIdentifier: self.declaration))"
  }
}
