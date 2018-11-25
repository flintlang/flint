//
//  TypeChecker+Expression.swift
//  TypeChecker
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

import AST
import Diagnostic

extension TypeChecker {
  public func process(binaryExpression: BinaryExpression,
                      passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    var diagnostics = [Diagnostic]()
    let environment = passContext.environment!
    var binaryExpression = binaryExpression

    // Check operand types match those required by the operators.
    let typeIdentifier = passContext.enclosingTypeIdentifier!
    let lhsType = environment.type(of: binaryExpression.lhs,
                                   enclosingType: typeIdentifier.name,
                                   scopeContext: passContext.scopeContext!)
    let rhsType = environment.type(of: binaryExpression.rhs,
                                   enclosingType: typeIdentifier.name,
                                   scopeContext: passContext.scopeContext!)

    switch binaryExpression.opToken {
    case .dot:
      binaryExpression.rhs = binaryExpression.rhs.assigningEnclosingType(type: lhsType.name)
    case .equal:
      // Both sides must have the same type.
      if ![lhsType, rhsType].contains(.errorType), !lhsType.isCompatible(with: rhsType, in: passContext) {
        diagnostics.append(.incompatibleAssignment(lhsType: lhsType,
                                                   rhsType: rhsType,
                                                   expression: .binaryExpression(binaryExpression)))
      }
    case .plus, .overflowingPlus, .minus, .overflowingMinus, .times, .overflowingTimes,
         .power, .divide, .plusEqual, .minusEqual, .timesEqual, .divideEqual,
         .openAngledBracket, .closeAngledBracket, .lessThanOrEqual, .greaterThanOrEqual:
      // Both sides must have type Int.
      if ![lhsType, rhsType].contains(.errorType),
        !lhsType.isCompatible(with: .basicType(.int)) ||
          !rhsType.isCompatible(with: .basicType(.int)) {
        diagnostics.append(
          .incompatibleOperandTypes(operatorKind: binaryExpression.opToken,
                                    lhsType: lhsType,
                                    rhsType: rhsType,
                                    expectedTypes: [.basicType(.int)],
                                    expression: .binaryExpression(binaryExpression)))
      }
    case .and, .or:
      // Both sides must have type Bool.
      if ![lhsType, rhsType].contains(.errorType),
        !lhsType.isCompatible(with: .basicType(.bool)) ||
          !rhsType.isCompatible(with: .basicType(.bool)) {
        diagnostics.append(
          .incompatibleOperandTypes(operatorKind: binaryExpression.opToken,
                                    lhsType: lhsType,
                                    rhsType: rhsType,
                                    expectedTypes: [.basicType(.bool)],
                                    expression: .binaryExpression(binaryExpression)))
      }
    case .doubleEqual, .notEqual:
      // Both sides must have the same type, and one of either Address, Bool, Int or String.
      if ![lhsType, rhsType].contains(.errorType), !lhsType.isCompatible(with: rhsType) {
        diagnostics.append(
          .unmatchedOperandTypes(operatorKind: binaryExpression.opToken,
                                 lhsType: lhsType,
                                 rhsType: rhsType,
                                 expression: .binaryExpression(binaryExpression)))
      }

      let acceptedTypes: [RawType] = [
        .basicType(.address),
        .basicType(.bool),
        .basicType(.int),
        .basicType(.string),
        .userDefinedType("Enum")
      ]

      if ![lhsType, rhsType].contains(.errorType),
        !acceptedTypes.contains(lhsType) &&
          !environment.isEnumDeclared(lhsType.name) {
        diagnostics.append(
          .incompatibleOperandTypes(operatorKind: binaryExpression.opToken,
                                    lhsType: lhsType,
                                    rhsType: rhsType,
                                    expectedTypes: acceptedTypes,
                                    expression: .binaryExpression(binaryExpression)))
      }
    case .at, .openBrace, .closeBrace, .openSquareBracket, .closeSquareBracket, .colon, .doubleColon,
         .openBracket, .closeBracket, .arrow, .leftArrow, .comma, .semicolon, .doubleSlash, .dotdot, .ampersand,
         .halfOpenRange, .closedRange, .bang, .question:
      // These are not valid binary operators.
      fatalError()
    }

    return ASTPassResult(element: binaryExpression, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    var diagnostics = [Diagnostic]()
    let environment = passContext.environment!
    let enclosingType = passContext.enclosingTypeIdentifier!.name
    let typeStates = passContext.contractBehaviorDeclarationContext?.typeStates ?? []
    let callerProtections = passContext.contractBehaviorDeclarationContext?.callerProtections ?? []

    if case .matchedEvent(let eventInformation) =
      environment.matchEventCall(functionCall,
                                 enclosingType: enclosingType,
                                 scopeContext: passContext.scopeContext ?? ScopeContext()) {

      // Ensure an event call's arguments match the expected types.

      for argument in functionCall.arguments {
        guard argument.identifier != nil else {
          // This will have been caught as a semantic error
          continue
        }

        let argumentType = environment.type(of: argument.expression,
                                            enclosingType: enclosingType,
                                            scopeContext: passContext.scopeContext!)
        let expectedType = eventInformation.declaration.variableDeclarations.filter {
          $0.identifier.name == argument.identifier?.name
        }.first?.type.rawType

        if argumentType != expectedType {
          diagnostics.append(
            .incompatibleArgumentType(actualType: argumentType,
                                      expectedType: expectedType!,
                                      expression: argument.expression))
        }
      }
    } else if case .matchedFunction(let matchingFunction) =
      environment.matchFunctionCall(functionCall,
                                    enclosingType: functionCall.identifier.enclosingType ?? enclosingType,
                                    typeStates: typeStates,
                                    callerProtections: callerProtections,
                                    scopeContext: passContext.scopeContext!) {

      if let externalCall = passContext.externalCallContext {
        // check value parameter (type)
        if matchingFunction.declaration.isPayable {
          if let valueParameter: FunctionArgument = externalCall.getHyperParameter(parameterName: "value") {
            let parameterType = environment.type(of: valueParameter.expression,
                                                 enclosingType: enclosingType,
                                                 typeStates: typeStates,
                                                 callerProtections: callerProtections,
                                                 scopeContext: passContext.scopeContext!)

            if parameterType != .userDefinedType(RawType.StdlibType.wei.rawValue) {
              diagnostics.append(.valueParameterWithWrongType(valueParameter))
            }
          }
        }

        // check gas parameter (type)
        if let gasParameter: FunctionArgument = externalCall.getHyperParameter(parameterName: "gas") {
          let parameterType = environment.type(of: gasParameter.expression,
              enclosingType: enclosingType,
              typeStates: typeStates,
              callerProtections: callerProtections,
              scopeContext: passContext.scopeContext!)

          if parameterType != .basicType(.int) {
            diagnostics.append(.gasParameterWithWrongType(gasParameter))
          }
        }
      }
    }

    return ASTPassResult(element: functionCall, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(externalCall: ExternalCall, passContext: ASTPassContext) -> ASTPassResult<ExternalCall> {
    var diagnostics = [Diagnostic]()
    let environment = passContext.environment!
    let enclosingType = passContext.enclosingTypeIdentifier!.name

    if externalCall.mode == .returnsGracefullyOptional && environment.type(of: externalCall.functionCall.rhs,
                          enclosingType: enclosingType,
                          scopeContext: passContext.scopeContext!) == .basicType(.void) {
      diagnostics.append(.optionalExternalCallWithoutReturnType(externalCall: externalCall))
    }

    return ASTPassResult(element: externalCall, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(subscriptExpression: SubscriptExpression,
                      passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    var diagnostics = [Diagnostic]()
    let environment = passContext.environment!
    let typeIdentifier = passContext.enclosingTypeIdentifier!
    let scopeContext = passContext.scopeContext!

    let identifierType = environment.type(of: subscriptExpression.baseExpression,
                                          enclosingType: typeIdentifier.name,
                                          scopeContext: scopeContext)

    let actualType = environment.type(of: subscriptExpression.indexExpression,
                                      enclosingType: typeIdentifier.name,
                                      scopeContext: scopeContext)
    var expectedType: RawType = .errorType

    switch identifierType {
    case .arrayType, .fixedSizeArrayType: expectedType = .basicType(.int)
    case .dictionaryType(let keyType, _): expectedType = keyType
    default:
      diagnostics.append(.incompatibleSubscript(actualType: identifierType,
                                                expression: subscriptExpression.baseExpression))
    }

    if !actualType.isCompatible(with: expectedType), ![actualType, expectedType].contains(.errorType) {
      diagnostics.append(.incompatibleSubscriptIndex(actualType: actualType,
                                                     expectedType: expectedType,
                                                     expression: .subscriptExpression(subscriptExpression)))
    }
    return ASTPassResult(element: subscriptExpression, diagnostics: diagnostics, passContext: passContext)
  }
}
