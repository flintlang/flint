//
//  VariableDeclaration.swift
//  YUL
//
//

public struct VariableDeclaration: CustomStringConvertible, Throwing {
  public let declaration: TypedIdentifier
  public private(set) var catchableSuccesses: [Expression] = []

  public init(_ declaration: TypedIdentifier) {
    self.declaration = declaration
  }

  public init(_ declaration: TypedIdentifier, _ deadParam: Any) {
    self.declaration = declaration
  }

  public var description: String {
    return "let \(render(typedIdentifier: self.declaration))"
  }
}
