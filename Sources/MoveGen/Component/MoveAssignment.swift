//
//  MoveAssignment.swift
//  MoveGen
//
//
import AST
import MoveIR

/// Generates code for an assignment.
struct MoveAssignment {
  var lhs: AST.Expression
  var rhs: AST.Expression

  func rendered(functionContext: FunctionContext, asTypeProperty: Bool = false) -> MoveIR.Expression {
    let rhsIr = MoveExpression(expression: rhs).rendered(functionContext: functionContext)

    switch lhs {
    case .variableDeclaration(let variableDeclaration):
      let mangledName = Mangler.mangleName(variableDeclaration.identifier.name)
      // Shadowed variables shouldn't be redeclared
      if mangledName == rhsIr.description {
        return .noop
      }
      let typeIR: MoveIR.`Type` = CanonicalType(
          from: variableDeclaration.type.rawType,
          environment: functionContext.environment
      )!.render(functionContext: functionContext)
      // FIXME any cannot be handled by MoveIR, please change -- is this fixed?
      return .variableDeclaration(MoveIR.VariableDeclaration((mangledName, typeIR)))
    case .identifier(let identifier) where identifier.enclosingType == nil:
      return .assignment(Assignment(identifier.name.mangled, rhsIr))
    case .rawAssembly(let string, _):
      // If this is a releasing assignment, force move the identifier to destroy it
      if string == "_",
         case .identifier(let identifier) = rhs {
        return .assignment(Assignment(
            "_",
            MoveIdentifier(identifier: identifier).rendered(functionContext: functionContext, forceMove: true)
        ))
      }
      fallthrough
    default:
      // LHS refers to a property in storage or memory.
      let lhsIr = MoveExpression(expression: lhs, position: .left).rendered(functionContext: functionContext)

      if functionContext.isInStructFunction {
        return .assignment(Assignment(lhsIr.description, rhsIr))
      } else if let enclosingIdentifier = lhs.enclosingIdentifier,
        functionContext.scopeContext.containsVariableDeclaration(for: enclosingIdentifier.name) {
        return .assignment(Assignment(enclosingIdentifier.name, rhsIr))
      } else {
        return .assignment(Assignment(lhsIr.description, rhsIr))
      }
    }
  }
}
