//
//  IRSubscriptExpression.swift
//  IRGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST
import YUL


/// Generates code for a subscript expression.
struct IRSubscriptExpression {
  var subscriptExpression: SubscriptExpression
  var asLValue: Bool

  func baseIdentifier(_ baseExpression: AST.Expression) -> AST.Identifier? {
    if case .identifier(let identifier) = baseExpression {
      return identifier
    }
    if case .subscriptExpression(let subscriptExpression) = baseExpression {
      return baseIdentifier(subscriptExpression.baseExpression)
    }
    return nil
  }

  func nestedStorageOffset(subExpr: SubscriptExpression, baseOffset: Int,
                           functionContext: FunctionContext) -> (String) {
    let indexExpressionCode = IRExpression(expression: subExpr.indexExpression)
      .rendered(functionContext: functionContext)
    let type = functionContext.environment.type(of: subExpr.baseExpression,
                                                enclosingType: functionContext.enclosingTypeName,
                                                scopeContext: functionContext.scopeContext)
    let runtimeFunc: (String, String) -> String

    switch type {
    case .arrayType:
      runtimeFunc = IRRuntimeFunction.storageArrayOffset
    case .fixedSizeArrayType:
      let typeSize = functionContext.environment.size(of: type)
      runtimeFunc = {IRRuntimeFunction.storageFixedSizeArrayOffset(arrayOffset: $0, index: $1, arraySize: typeSize)}
    case .dictionaryType:
      runtimeFunc = IRRuntimeFunction.storageDictionaryOffsetForKey
    default: fatalError("Invalid type")
    }

    switch subExpr.baseExpression {
    case .identifier:
      return (runtimeFunc(String(baseOffset), indexExpressionCode.description))
    case .subscriptExpression(let newBase):
      let e = nestedStorageOffset(subExpr: newBase,
                          baseOffset: baseOffset,
                          functionContext: functionContext)

      return (runtimeFunc(e.description, indexExpressionCode.description))
    default:
      fatalError("Subscript expression has an invalid type")
    }
  }

  func rendered(functionContext: FunctionContext) -> YUL.Expression {
    guard let identifier = baseIdentifier(.subscriptExpression(subscriptExpression)),
      let enclosingType = identifier.enclosingType,
      let baseOffset = functionContext.environment.propertyOffset(for: identifier.name,
                                                                  enclosingType: enclosingType) else {
        fatalError("Arrays and dictionaries cannot be defined as local variables yet.")
    }

    let (memLocation): (String) = nestedStorageOffset(subExpr: subscriptExpression,
                                                  baseOffset: baseOffset,
                                                  functionContext: functionContext)

    if asLValue {
      return .inline(memLocation)
    } else {
      return .inline("sload(\(memLocation))")
    }
  }
}
