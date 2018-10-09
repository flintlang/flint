//
//  Environment+Type.swift
//  AST
//
//  Created by Hails, Daniel J R on 22/08/2018.
//
import Lexer

extension Environment {
  /// The type of a property in the given enclosing type or in a scope if it is a local variable.
  public func type(of property: String, enclosingType: RawTypeIdentifier,
                   scopeContext: ScopeContext? = nil) -> RawType {
    if let type = types[enclosingType]?.properties[property]?.rawType {
      return type
    }

    if let function = types[enclosingType]?.functions[property]?.first! {
      return .functionType(parameters: function.parameterTypes, result: function.resultType)
    }

    guard let scopeContext = scopeContext, let type = scopeContext.type(for: property) else { return .errorType }
    return type
  }

  /// The type return type of a function call, determined by looking up the function's declaration.
  public func type(of functionCall: FunctionCall,
                   enclosingType: RawTypeIdentifier,
                   typeStates: [TypeState],
                   callerProtections: [CallerProtection],
                   scopeContext: ScopeContext) -> RawType? {
    let match = matchFunctionCall(functionCall, enclosingType: enclosingType, typeStates: typeStates,
                                  callerProtections: callerProtections, scopeContext: scopeContext)

    switch match {
    case .matchedFunction(let matchingFunction): return matchingFunction.resultType
    case .matchedFunctionWithoutCaller(let matchingFunctions):
      guard matchingFunctions.count == 1,
        case .functionInformation(let functionInformation) = matchingFunctions.first! else {
        return .errorType
      }
      return functionInformation.resultType
    case .matchedInitializer:
      let name = functionCall.identifier.name
      if let stdlibType = RawType.StdlibType(rawValue: name) {
        return .stdlibType(stdlibType)
      }
      return .userDefinedType(name)
    default:
      let eventMatch = matchEventCall(functionCall, enclosingType: enclosingType, scopeContext: scopeContext)
      switch eventMatch {
      case .matchedEvent(let event):
        return .userDefinedType(event.declaration.identifier.name)
      case .failure:
        return .errorType
      }
    }
  }

  /// The types a literal token can be.
  public func type(ofLiteralToken literalToken: Token) -> RawType {
    guard case .literal(let literal) = literalToken.kind else { fatalError() }
    switch literal {
    case .boolean: return .basicType(.bool)
    case .decimal(.integer): return .basicType(.int)
    case .string: return .basicType(.string)
    case .address: return .basicType(.address)
    default: fatalError()
    }
  }

  // The type of an array literal.
  public func type(ofArrayLiteral arrayLiteral: ArrayLiteral,
                   enclosingType: RawTypeIdentifier,
                   scopeContext: ScopeContext) -> RawType {
    var elementType: RawType?

    for element in arrayLiteral.elements {
      let _type = type(of: element, enclosingType: enclosingType, scopeContext: scopeContext)

      if let elementType = elementType, elementType != _type {
        // The elements have different types.
        return .errorType
      }

      if elementType == nil {
        elementType = _type
      }
    }

    return .arrayType(elementType ?? .any)
  }

  // The type of a range.
  public func type(ofRangeExpression rangeExpression: RangeExpression,
                   enclosingType: RawTypeIdentifier,
                   scopeContext: ScopeContext) -> RawType {
    let elementType = type(of: rangeExpression.initial, enclosingType: enclosingType, scopeContext: scopeContext)
    let boundType   = type(of: rangeExpression.bound, enclosingType: enclosingType, scopeContext: scopeContext)

    if elementType != boundType {
      // The bounds have different types.
      return .errorType
    }

    return .rangeType(elementType)
  }

  // The type of a dictionary literal.
  public func type(ofDictionaryLiteral dictionaryLiteral: DictionaryLiteral,
                   enclosingType: RawTypeIdentifier,
                   scopeContext: ScopeContext) -> RawType {
    var keyType: RawType?
    var valueType: RawType?

    for element in dictionaryLiteral.elements {
      let _keyType = type(of: element.key, enclosingType: enclosingType, scopeContext: scopeContext)
      let _valueType = type(of: element.value, enclosingType: enclosingType, scopeContext: scopeContext)

      if let _keyType = keyType, _keyType != keyType {
        // The keys have conflicting types.
        return .errorType
      }

      if let _valueType = valueType, _valueType != valueType {
        // The values have conflicting types.
        return .errorType
      }

      if keyType == nil {
        keyType = _keyType
      }

      if valueType == nil {
        valueType = _valueType
      }
    }

    return .dictionaryType(key: keyType ?? .any, value: valueType ?? .any)
  }

  public func type(of attemptExpression: AttemptExpression,
                   enclosingType: RawTypeIdentifier,
                   typeStates: [TypeState],
                   callerProtections: [CallerProtection] = [],
                   scopeContext: ScopeContext) -> RawType {
    if attemptExpression.isSoft {
     return .basicType(.bool)
    }
    let functionCall = attemptExpression.functionCall
    return type(of: functionCall,
                enclosingType: functionCall.identifier.enclosingType ?? enclosingType,
                typeStates: typeStates,
                callerProtections: callerProtections,
                scopeContext: scopeContext) ?? .errorType
  }

  /// The type of an expression.
  ///
  /// - Parameters:
  ///   - expression: The expression to compute the type for.
  ///   - functionDeclarationContext: Contextual information if the expression is used in a function.
  ///   - enclosingType: The enclosing type of the expression, if any.
  ///   - callerProtections: The caller protections associated with the expression,
  ///                        if the expression is a function call.
  ///   - scopeContext: Contextual information about the scope in which the expression resides.
  /// - Returns: The `RawType` of the expression.
  public func type(of expression: Expression,
                   enclosingType: RawTypeIdentifier,
                   typeStates: [TypeState] = [],
                   callerProtections: [CallerProtection] = [],
                   scopeContext: ScopeContext) -> RawType {

    switch expression {
    case .inoutExpression(let inoutExpression):
      return .inoutType(type(of: inoutExpression.expression,
                             enclosingType: enclosingType,
                             typeStates: typeStates,
                             callerProtections: callerProtections,
                             scopeContext: scopeContext))

    case .binaryExpression(let binaryExpression):
      if binaryExpression.opToken.isBooleanOperator {
        return .basicType(.bool)
      }

      if binaryExpression.opToken == .dot {
        switch type(of: binaryExpression.lhs,
                    enclosingType: enclosingType,
                    typeStates: typeStates,
                    callerProtections: callerProtections,
                    scopeContext: scopeContext) {
        case .arrayType:
          if case .identifier(let identifier) = binaryExpression.rhs, identifier.name == "size" {
            return .basicType(.int)
          } else {
            fatalError()
          }
        case .fixedSizeArrayType:
          if case .identifier(let identifier) = binaryExpression.rhs, identifier.name == "size" {
            return .basicType(.int)
          } else {
            fatalError()
          }
        case .dictionaryType:
          if case .identifier(let identifier) = binaryExpression.rhs, identifier.name == "size" {
            return .basicType(.int)
          } else {
            fatalError()
          }
        default:
          break
        }
      }

      return type(of: binaryExpression.rhs,
                  enclosingType: enclosingType,
                  typeStates: typeStates,
                  callerProtections: callerProtections,
                  scopeContext: scopeContext)

    case .bracketedExpression(let bracketedExpression):
      return type(of: bracketedExpression.expression,
                  enclosingType: enclosingType,
                  typeStates: typeStates,
                  callerProtections: callerProtections,
                  scopeContext: scopeContext)

    case .functionCall(let functionCall):
      return type(of: functionCall,
                  enclosingType: functionCall.identifier.enclosingType ?? enclosingType,
                  typeStates: typeStates,
                  callerProtections: callerProtections,
                  scopeContext: scopeContext) ?? .errorType

    case .identifier(let identifier):
      if identifier.enclosingType == nil,
        let type = scopeContext.type(for: identifier.name) {
        if case .inoutType(let type) = type {
          return type
        }
        return type
      }
      return type(of: identifier.name,
                  enclosingType: identifier.enclosingType ?? enclosingType,
                  scopeContext: scopeContext)

    case .self: return .userDefinedType(enclosingType)
    case .variableDeclaration(let variableDeclaration):
      return variableDeclaration.type.rawType
    case .subscriptExpression(let subscriptExpression):
      let identifierType = type(of: subscriptExpression.baseExpression,
                                enclosingType: enclosingType,
                                scopeContext: scopeContext)

      switch identifierType {
      case .arrayType(let elementType): return elementType
      case .fixedSizeArrayType(let elementType, _): return elementType
      case .dictionaryType(_, let valueType): return valueType
      default: return .errorType
      }
    case .literal(let literalToken): return type(ofLiteralToken: literalToken)
    case .arrayLiteral(let arrayLiteral):
      return type(ofArrayLiteral: arrayLiteral, enclosingType: enclosingType, scopeContext: scopeContext)
    case .range(let rangeExpression):
      return type(ofRangeExpression: rangeExpression, enclosingType: enclosingType, scopeContext: scopeContext)
    case .attemptExpression(let attemptExpression):
       return type(of: attemptExpression,
                   enclosingType: enclosingType,
                   typeStates: typeStates,
                   callerProtections: callerProtections,
                   scopeContext: scopeContext)
    case .dictionaryLiteral(let dictionaryLiteral):
      return type(ofDictionaryLiteral: dictionaryLiteral, enclosingType: enclosingType, scopeContext: scopeContext)
    case .sequence: fatalError()
    case .rawAssembly(_, let resultType): return resultType!
    }
  }
}
