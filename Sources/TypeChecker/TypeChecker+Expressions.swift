//
//  TypeChecker+Expression.swift
//  TypeChecker
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

import AST
import Diagnostic

extension TypeChecker {
  public func process(binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    var diagnostics = [Diagnostic]()
    let environment = passContext.environment!
    var binaryExpression = binaryExpression

    // Check operand types match those required by the operators.
    let typeIdentifier = passContext.enclosingTypeIdentifier!
    let lhsType = environment.type(of: binaryExpression.lhs, enclosingType: typeIdentifier.name, scopeContext: passContext.scopeContext!)
    let rhsType = environment.type(of: binaryExpression.rhs, enclosingType: typeIdentifier.name, scopeContext: passContext.scopeContext!)

    switch binaryExpression.opToken {
    case .dot:
      binaryExpression.rhs = binaryExpression.rhs.assigningEnclosingType(type: lhsType.name)
    case .equal:
      // Both sides must have the same type.
      if ![lhsType, rhsType].contains(.errorType), !lhsType.isCompatible(with: rhsType) {
        diagnostics.append(.incompatibleAssignment(lhsType: lhsType, rhsType: rhsType, expression: .binaryExpression(binaryExpression)))
      }
    case .plus, .overflowingPlus, .minus, .overflowingMinus, .times, .overflowingTimes, .power, .divide, .plusEqual, .minusEqual, .timesEqual, .divideEqual, .openAngledBracket, .closeAngledBracket, .lessThanOrEqual, .greaterThanOrEqual:
      // Both sides must have type Int.
      if ![lhsType, rhsType].contains(.errorType), !lhsType.isCompatible(with: .basicType(.int)) || !rhsType.isCompatible(with: .basicType(.int)) {
        diagnostics.append(.incompatibleOperandTypes(operatorKind: binaryExpression.opToken, lhsType: lhsType, rhsType: rhsType, expectedTypes: [.basicType(.int)], expression: .binaryExpression(binaryExpression)))
      }
    case .and, .or:
      // Both sides must have type Bool.
      if ![lhsType, rhsType].contains(.errorType), !lhsType.isCompatible(with: .basicType(.bool)) || !rhsType.isCompatible(with: .basicType(.bool)) {
        diagnostics.append(.incompatibleOperandTypes(operatorKind: binaryExpression.opToken, lhsType: lhsType, rhsType: rhsType, expectedTypes: [.basicType(.bool)], expression: .binaryExpression(binaryExpression)))
      }
    case .doubleEqual, .notEqual:
      // Both sides must have the same type, and one of either Address, Bool, Int or String.
      if ![lhsType, rhsType].contains(.errorType), !lhsType.isCompatible(with: rhsType) {
        diagnostics.append(.unmatchedOperandTypes(operatorKind: binaryExpression.opToken, lhsType: lhsType, rhsType: rhsType, expression: .binaryExpression(binaryExpression)))
      }
      let acceptedTypes: [RawType] = [.basicType(.address), .basicType(.bool), .basicType(.int), .basicType(.string), .userDefinedType("Enum")]
      if ![lhsType, rhsType].contains(.errorType), !acceptedTypes.contains(lhsType) && !environment.isEnumDeclared(lhsType.name) {
        diagnostics.append(.incompatibleOperandTypes(operatorKind: binaryExpression.opToken, lhsType: lhsType, rhsType: rhsType, expectedTypes: acceptedTypes, expression: .binaryExpression(binaryExpression)))
      }
    case .at, .openBrace, .closeBrace, .openSquareBracket, .closeSquareBracket, .colon, .doubleColon, .openBracket, .closeBracket, .arrow, .leftArrow, .comma, .semicolon, .doubleSlash, .dotdot, .ampersand, .halfOpenRange, .closedRange:
      // These are not valid binary operators.
      fatalError()
    }

    return ASTPassResult(element: binaryExpression, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    var diagnostics = [Diagnostic]()
    let environment = passContext.environment!
    let enclosingType = passContext.enclosingTypeIdentifier!.name

    if let eventCall = environment.matchEventCall(functionCall, enclosingType: enclosingType) {
      let expectedTypes = eventCall.typeGenericArguments

      // Ensure an event call's arguments match the expected types.

      for (i, argument) in functionCall.arguments.enumerated() {
        let argumentType = environment.type(of: argument, enclosingType: enclosingType, scopeContext: passContext.scopeContext!)
        let expectedType = expectedTypes[i]
        if argumentType != expectedType {
          diagnostics.append(.incompatibleArgumentType(actualType: argumentType, expectedType: expectedType, expression: argument))
        }
      }
    }

    return ASTPassResult(element: functionCall, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    var diagnostics = [Diagnostic]()
    let environment = passContext.environment!
    let typeIdentifier = passContext.enclosingTypeIdentifier!
    let scopeContext = passContext.scopeContext!

    let identifierType = environment.type(of: subscriptExpression.baseExpression, enclosingType: typeIdentifier.name, scopeContext: scopeContext)

    let actualType = environment.type(of: subscriptExpression.indexExpression, enclosingType: typeIdentifier.name, scopeContext: scopeContext)
    var expectedType: RawType = .errorType

    switch identifierType {
    case .arrayType (_), .fixedSizeArrayType(_): expectedType = .basicType(.int)
    case .dictionaryType(let keyType, _): expectedType = keyType
    default:
      diagnostics.append(.incompatibleSubscript(actualType: identifierType, expression: subscriptExpression.baseExpression))
    }

    if !actualType.isCompatible(with: expectedType), ![actualType, expectedType].contains(.errorType) {
      diagnostics.append(.incompatibleSubscriptIndex(actualType: actualType, expectedType: expectedType, expression: .subscriptExpression(subscriptExpression)))
    }
    return ASTPassResult(element: subscriptExpression, diagnostics: diagnostics, passContext: passContext)
  }
}
