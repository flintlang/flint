//
//  IRPropertyAccess.swift
//  IRGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST

/// Generates code for a property access.
struct IRPropertyAccess {
  var lhs: Expression
  var rhs: Expression
  var asLValue: Bool

  func rendered(functionContext: FunctionContext) -> String {
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
      return IRExpression(expression: propertyInformation.property.value!).rendered(functionContext: functionContext)
    }

    let rhsOffset: String
    // Special cases.
    switch lhsType {
    case .fixedSizeArrayType(_, let size):
      if case .identifier(let identifier) = rhs, identifier.name == "size" {
        return "\(size)"
      } else {
        fatalError()
      }
    case .arrayType(_):
      if case .identifier(let identifier) = rhs, identifier.name == "size" {
        rhsOffset = "0"
      } else {
        fatalError()
      }
    case .dictionaryType(_):
      if case .identifier(let identifier) = rhs, identifier.name == "size" {
        rhsOffset = "0"
      } else {
        fatalError()
      }
    default:
      rhsOffset = IRPropertyOffset(expression: rhs, enclosingType: lhsType).rendered(functionContext: functionContext)
    }

    let offset: String
    if isInStructFunction {
      let enclosingName: String
      if let enclosingParameter = functionContext.scopeContext.enclosingParameter(expression: lhs, enclosingTypeName: functionContext.enclosingTypeName) {
        enclosingName = enclosingParameter
      } else {
        enclosingName = "flintSelf"
      }

      // For struct parameters, access the property by an offset to _flintSelf (the receiver's address).
      offset = IRRuntimeFunction.addOffset(base: enclosingName.mangled, offset: rhsOffset, inMemory: Mangler.isMem(for: enclosingName).mangled)
    } else {
      let lhsOffset: String
      if case .identifier(let lhsIdentifier) = lhs {
        if let enclosingType = lhsIdentifier.enclosingType, let offset = environment.propertyOffset(for: lhsIdentifier.name, enclosingType: enclosingType) {
          lhsOffset = "\(offset)"
        } else if functionContext.scopeContext.containsVariableDeclaration(for: lhsIdentifier.name) {
          lhsOffset = lhsIdentifier.name.mangled
          isMemoryAccess = true
        } else {
          lhsOffset = "\(environment.propertyOffset(for: lhsIdentifier.name, enclosingType: enclosingTypeName)!)"
        }
      } else {
        lhsOffset = IRExpression(expression: lhs, asLValue: true).rendered(functionContext: functionContext)
      }

      offset = IRRuntimeFunction.addOffset(base: lhsOffset, offset: rhsOffset, inMemory: isMemoryAccess)
    }

    if asLValue {
      return offset
    }

    if isInStructFunction, !isMemoryAccess {
      let lhsEnclosingIdentifier = lhs.enclosingIdentifier?.name.mangled ?? "flintSelf".mangled
      return IRRuntimeFunction.load(address: offset, inMemory: Mangler.isMem(for: lhsEnclosingIdentifier))
    }

    return IRRuntimeFunction.load(address: offset, inMemory: isMemoryAccess)
  }
}
