//
//  MovePropertyAccess.swift
//  MoveGen
//
//
import AST
import MoveIR

/// Generates code for a property access.
struct MovePropertyAccess {
  var lhs: AST.Expression
  var rhs: AST.Expression
  var position: Position

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
    let environment = functionContext.environment

    if case .identifier(let enumIdentifier) = lhs,
      case .identifier(let propertyIdentifier) = rhs,
      environment.isEnumDeclared(enumIdentifier.name),
      let propertyInformation = environment.property(propertyIdentifier.name, enumIdentifier.name) {
      return MoveExpression(expression: propertyInformation.property.value!, position: position)
          .rendered(functionContext: functionContext)
    }
    if let rhsId = rhs.enclosingIdentifier {
      if functionContext.isConstructor {
        return MoveIdentifier(identifier: rhsId, position: position).rendered(functionContext: functionContext)
      }
      let lhsExpr = MoveExpression(expression: lhs, position: (position == .inOut ? .inOut : .accessed))
          .rendered(functionContext: functionContext)
      return .operation(.access(lhsExpr, rhsId.name))
    }
    fatalError()
  }
}
