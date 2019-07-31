//
//  VariableDeclaration.swift
//  YUL
//
//  Created by Aurel Bílý on 12/26/18.
//

public struct VariableDeclaration: CustomStringConvertible, Throwing {
  public let declarations: [TypedIdentifier]
  public let expression: Expression?

  public init(_ declarations: [TypedIdentifier], _ expression: Expression? = nil) {
    self.declarations = declarations
    self.expression = expression
  }

  public var catchableSuccesses: [Expression] {
    return expression?.catchableSuccesses ?? []
  }

  public var description: String {
    let decls = render(typedIdentifiers: self.declarations)
    if self.expression == nil {
      return "let \(decls);"
    }
    // FIXME This is wrong in move, all declarations must be seperate 
    // from assignment and be at the top
    return "let \(decls) = \(self.expression!.description);"
  }
}
