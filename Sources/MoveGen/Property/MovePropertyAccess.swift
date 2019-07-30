//
//  MovePropertyAccess.swift
//  MoveGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST
import MoveIR

/// Generates code for a property access.
struct MovePropertyAccess {
  var lhs: AST.Expression
  var rhs: AST.Expression
  var asLValue: Bool

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
    let environment = functionContext.environment
    let scopeContext = functionContext.scopeContext
    let enclosingTypeName = functionContext.enclosingTypeName
    let isInStructFunction = functionContext.isInStructFunction

    var isMemoryAccess: Bool = false

    let lhsType = environment.type(of: lhs, enclosingType: enclosingTypeName, scopeContext: scopeContext)

    if case .identifier(let enumIdentifier) = lhs,
      case .identifier(let propertyIdentifier) = rhs,
      environment.isEnumDeclared(enumIdentifier.name),
      let propertyInformation = environment.property(propertyIdentifier.name, enumIdentifier.name) {
      return MoveExpression(expression: propertyInformation.property.value!).rendered(functionContext: functionContext)
    }

    let rhsOffset: MoveIR.Expression
    // Special cases.
    switch lhsType {
    case .fixedSizeArrayType(_, let size):
      if case .identifier(let identifier) = rhs, identifier.name == "size" {
        return .literal(.num(size))
      } else {
        fatalError()
      }
    case .arrayType:
      if case .identifier(let identifier) = rhs, identifier.name == "size" {
        rhsOffset = .literal(.num(0))
      } else {
        fatalError()
      }
    case .dictionaryType:
      if case .identifier(let identifier) = rhs, identifier.name == "size" {
        rhsOffset = .literal(.num(0))
      } else {
        fatalError()
      }
    default:
      rhsOffset = MovePropertyOffset(expression: rhs, enclosingType: lhsType).rendered(functionContext: functionContext)
    }

    let offset: MoveIR.Expression

    if isInStructFunction {
      let enclosingName: String
      if let enclosingParameter =
        functionContext.scopeContext.enclosingParameter(expression: lhs,
                                                        enclosingTypeName: functionContext.enclosingTypeName) {
        enclosingName = enclosingParameter
      } else {
        enclosingName = "flintSelf"
      }

      // For struct parameters, access the property by an offset to _flintSelf (the receiver's address).
      offset = MoveRuntimeFunction.addOffset(base: .identifier(enclosingName.mangled),
                                           offset: rhsOffset,
                                           inMemory: Mangler.isMem(for: enclosingName).mangled)
    } else {
      let lhsOffset: MoveIR.Expression
      if case .identifier(let lhsIdentifier) = lhs {
        if let enclosingType = lhsIdentifier.enclosingType,
            let offset = environment.propertyOffset(for: lhsIdentifier.name, enclosingType: enclosingType) {
          lhsOffset = .literal(.num(offset))
        } else if functionContext.scopeContext.containsVariableDeclaration(for: lhsIdentifier.name) {
          lhsOffset = .identifier(lhsIdentifier.name.mangled)
          isMemoryAccess = true
        } else {
          lhsOffset = .literal(.num(environment.propertyOffset(for: lhsIdentifier.name,
                                                               enclosingType: enclosingTypeName)!))
        }
      } else {
        lhsOffset = MoveExpression(expression: lhs, asLValue: true).rendered(functionContext: functionContext)
      }

      offset = MoveRuntimeFunction.addOffset(base: lhsOffset, offset: rhsOffset, inMemory: isMemoryAccess)
    }

    if asLValue {
      return offset
    }

    if isInStructFunction, !isMemoryAccess {
      let lhsEnclosingIdentifier = lhs.enclosingIdentifier?.name.mangled ?? "flintSelf".mangled
      return MoveRuntimeFunction.load(address: offset,
                                    inMemory: Mangler.isMem(for: lhsEnclosingIdentifier))
    }

    return MoveRuntimeFunction.load(address: offset, inMemory: isMemoryAccess)
  }
}
