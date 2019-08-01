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

  public var assignment: Assignment? {
    return self.expression.map { (expression: Expression) in
      return Assignment(declaration.0, expression)
    }
  }

  public var description: String {
    // FIXME This is wrong in move, all declarations must be seperate 
    // from assignment and be at the top
    // return "let \(decls) = \(self.expression!.description)"
    return "let \(render(typedIdentifier: self.declaration))"
  }
}
