//
//  IRSubscriptExpression.swift
//  IRGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST

/// Generates code for a subscript expression.
struct IRSubscriptExpression {
  var subscriptExpression: SubscriptExpression
  var asLValue: Bool

  func baseIdentifier(_ baseExpression: Expression) -> AST.Identifier? {
    if case .identifier(let identifier) = baseExpression {
      return identifier
    }
    if case .subscriptExpression(let subscriptExpression) = baseExpression {
      return baseIdentifier(subscriptExpression.baseExpression)
    }
    return nil
  }

  func nestedStorageOffset(subExpr: SubscriptExpression, baseOffset: Int,
                           functionContext: FunctionContext) -> (String, String) {
    let indexExpressionCode = IRExpression(expression: subExpr.indexExpression)
      .rendered(functionContext: functionContext)
    let preamble = indexExpressionCode.preamble

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
      return (preamble, runtimeFunc(String(baseOffset), indexExpressionCode.expression))
    case .subscriptExpression(let newBase):
      let e = nestedStorageOffset(subExpr: newBase,
                          baseOffset: baseOffset,
                          functionContext: functionContext)

      return (preamble + "\n" + e.0, runtimeFunc(e.1, indexExpressionCode.expression))
    default:
      fatalError("Subscript expression has an invalid type")
    }
  }

  func rendered(functionContext: FunctionContext) -> ExpressionFragment {
    guard let identifier = baseIdentifier(.subscriptExpression(subscriptExpression)),
      let enclosingType = identifier.enclosingType,
      let baseOffset = functionContext.environment.propertyOffset(for: identifier.name,
                                                                  enclosingType: enclosingType) else {
        fatalError("Arrays and dictionaries cannot be defined as local variables yet.")
    }

    let (preamble, memLocation): (String, String) = nestedStorageOffset(subExpr: subscriptExpression,
                                                  baseOffset: baseOffset,
                                                  functionContext: functionContext)

    if asLValue {
      return ExpressionFragment(pre: preamble, memLocation)
    } else {
      return ExpressionFragment(pre: preamble, "sload(\(memLocation))")
    }
  }
}
