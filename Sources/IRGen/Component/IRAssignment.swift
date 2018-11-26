//
//  IRAssignment.swift
//  IRGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST
import YUL

/// Generates code for an assignment.
struct IRAssignment {
  var lhs: AST.Expression
  var rhs: AST.Expression

  func rendered(functionContext: FunctionContext, asTypeProperty: Bool = false) -> YUL.Expression {
    let rhsIr = IRExpression(expression: rhs).rendered(functionContext: functionContext)
    let rhsCode = rhsIr.description

    switch lhs {
    case .variableDeclaration(let variableDeclaration):
      let mangledName = Mangler.mangleName(variableDeclaration.identifier.name)
      // Shadowed variables shouldn't be redeclared
      if mangledName == rhsCode {
        return .inline("")
      }
      return .inline("let \(mangledName) := \(rhsCode)")
    case .identifier(let identifier) where identifier.enclosingType == nil:
      return .inline("\(identifier.name.mangled) := \(rhsCode)")
    default:
      // LHS refers to a property in storage or memory.

      let lhsCode = IRExpression(expression: lhs, asLValue: true).rendered(functionContext: functionContext).description

      if functionContext.isInStructFunction {
        let enclosingName: String
        if let enclosingParameter = functionContext.scopeContext.enclosingParameter(
            expression: lhs,
            enclosingTypeName: functionContext.enclosingTypeName) {
          enclosingName = enclosingParameter
        } else {
          enclosingName = "flintSelf"
        }
        return .inline(IRRuntimeFunction.store(address: lhsCode,
                                               value: rhsCode,
                                               inMemory: Mangler.isMem(for: enclosingName).mangled))

      } else if let enclosingIdentifier = lhs.enclosingIdentifier,
        functionContext.scopeContext.containsVariableDeclaration(for: enclosingIdentifier.name) {
        return .inline(IRRuntimeFunction.store(address: lhsCode, value: rhsCode, inMemory: true))
      } else {
        return .inline(IRRuntimeFunction.store(address: lhsCode, value: rhsCode, inMemory: false))
      }
    }
  }
}
