//
//  FieldDeclaration.swift
//  flintc
//
//  Created by matteo on 06/08/2019.
//

public struct FieldDeclaration: CustomStringConvertible, Throwing {
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
    return "\(render(typedIdentifier: self.declaration))"
  }
}
