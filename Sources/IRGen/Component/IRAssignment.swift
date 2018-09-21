//
//  IRAssignment.swift
//  IRGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST

/// Generates code for an assignment.
struct IRAssignment {
  var lhs: Expression
  var rhs: Expression

  func rendered(functionContext: FunctionContext, asTypeProperty: Bool = false) -> String {
    let rhsCode = IRExpression(expression: rhs).rendered(functionContext: functionContext)

    switch lhs {
    case .variableDeclaration(let variableDeclaration):
      let mangledName = Mangler.mangleName(variableDeclaration.identifier.name)
      // Shadowed variables shouldn't be redeclared
      if mangledName == rhsCode {
        return ""
      }
      return "let \(mangledName) := \(rhsCode)"
    case .identifier(let identifier) where identifier.enclosingType == nil:
      return "\(identifier.name.mangled) := \(rhsCode)"
    default:
      // LHS refers to a property in storage or memory.
      let lhsCode = IRExpression(expression: lhs, asLValue: true).rendered(functionContext: functionContext)

      if functionContext.isInStructFunction {
        let enclosingName: String
        if let enclosingParameter = functionContext.scopeContext.enclosingParameter(expression: lhs, enclosingTypeName: functionContext.enclosingTypeName) {
          enclosingName = enclosingParameter
        } else {
          enclosingName = "flintSelf"
        }
        return IRRuntimeFunction.store(address: lhsCode, value: rhsCode, inMemory: Mangler.isMem(for: enclosingName).mangled)
      } else if let enclosingIdentifier = lhs.enclosingIdentifier,
        functionContext.scopeContext.containsVariableDeclaration(for: enclosingIdentifier.name) {
        return IRRuntimeFunction.store(address: lhsCode, value: rhsCode, inMemory: true)
      } else {
        return IRRuntimeFunction.store(address: lhsCode, value: rhsCode, inMemory: false)
      }
    }
  }
}
