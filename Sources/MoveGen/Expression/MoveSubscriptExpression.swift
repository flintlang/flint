//
//  MoveSubscriptExpression.swift
//  MoveGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST
import MoveIR

/// Generates code for a subscript expression.
struct MoveSubscriptExpression {
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
                           functionContext: FunctionContext) -> MoveIR.Expression {
    let indexExpressionCode = MoveExpression(expression: subExpr.indexExpression)
      .rendered(functionContext: functionContext)
    let type = functionContext.environment.type(of: subExpr.baseExpression,
                                                enclosingType: functionContext.enclosingTypeName,
                                                scopeContext: functionContext.scopeContext)
    fatalError("Subscript expression has an invalid type")
    /*
    let runtimeFunc: (MoveIR.Expression, MoveIR.Expression) -> MoveIR.Expression
    switch type {
    case .arrayType:
      runtimeFunc =
    case .fixedSizeArrayType:
      let typeSize = functionContext.environment.size(of: type)
      runtimeFunc = {MoveRuntimeFunction.storageFixedSizeArrayOffset(arrayOffset: $0, index: $1, arraySize: typeSize)}
    case .dictionaryType:
      runtimeFunc = MoveRuntimeFunction.storageDictionaryOffsetForKey
    default: fatalError("Invalid type")
    }

    switch subExpr.baseExpression {
    case .identifier:
      return runtimeFunc(.literal(.num(baseOffset)), indexExpressionCode)
    case .subscriptExpression(let newBase):
      let e = nestedStorageOffset(subExpr: newBase,
                          baseOffset: baseOffset,
                          functionContext: functionContext)

      return runtimeFunc(e, indexExpressionCode)
    default:
      fatalError()
    }*/
  }

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
    guard let identifier = baseIdentifier(.subscriptExpression(subscriptExpression)),
      let enclosingType = identifier.enclosingType,
      let baseOffset = functionContext.environment.propertyOffset(for: identifier.name,
                                                                  enclosingType: enclosingType) else {
        fatalError("Arrays and dictionaries cannot be defined as local variables yet.")
    }

    let memLocation = nestedStorageOffset(subExpr: subscriptExpression,
                                          baseOffset: baseOffset,
                                          functionContext: functionContext)

    if asLValue {
      return memLocation
    } else {
      return .functionCall(FunctionCall("sload", memLocation))
    }
  }
}
