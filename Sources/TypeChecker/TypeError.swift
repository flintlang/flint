//
//  TypeError.swift
//  TypeChecker
//
//  Created by Franklin Schrans on 1/11/18.
//

import AST
import Diagnostic
import Lexer

extension Diagnostic {
  static func incompatibleReturnType(actualType: RawType, expectedType: RawType, expression: Expression) -> Diagnostic {
    return Diagnostic(
      severity: .error, sourceLocation: expression.sourceLocation,
      message: "Cannot convert expression of type '\(actualType.name)' to expected return type '\(expectedType.name)'")
  }

  static func invalidState(falseState: Expression, contract: RawTypeIdentifier) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: falseState.sourceLocation,
                      message: "State not defined for contract '\(contract)'")
  }

  static func incompatibleForIterableType(iterableType: RawType, statement: Statement) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: statement.sourceLocation,
                      message: "Invalid iterable type '\(iterableType.name)'")
  }

  static func incompatibleForVariableType(varType: RawType, valueType: RawType, statement: Statement) -> Diagnostic {
    return Diagnostic(
      severity: .error, sourceLocation: statement.sourceLocation,
      message: "Cannot convert variable of type '\(varType.name)' to expected iterable value type '\(valueType.name)'")
  }

  static func incompatibleAssignment(lhsType: RawType, rhsType: RawType, expression: Expression) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: expression.sourceLocation,
                      message: "Incompatible assignment between values of type '\(lhsType.name)' and '\(rhsType.name)'")
  }

  static func incompatibleOperandTypes(operatorKind: Token.Kind.Punctuation,
                                       lhsType: RawType,
                                       rhsType: RawType,
                                       expectedTypes: [RawType],
                                       expression: Expression) -> Diagnostic {
    let notes = expectedTypes.map { expectedType in
      return Diagnostic(severity: .note, sourceLocation: expression.sourceLocation,
                        message: "Expected operands to be of type \(expectedType.name)")
    }

    return Diagnostic(
      severity: .error, sourceLocation: expression.sourceLocation,
      message: "Incompatible use of operator '\(operatorKind.rawValue)' on values " +
               "of types '\(lhsType.name)' and '\(rhsType.name)'",
      notes: notes)
  }

  static func unmatchedOperandTypes(operatorKind: Token.Kind.Punctuation,
                                    lhsType: RawType,
                                    rhsType: RawType,
                                    expression: Expression) -> Diagnostic {
    return Diagnostic(
      severity: .error, sourceLocation: expression.sourceLocation,
      message: "Incompatible use of operator '\(operatorKind.rawValue)' on values " +
                "of unmatched types '\(lhsType.name)' and '\(rhsType.name)'")
  }

  static func incompatibleArgumentType(actualType: RawType,
                                       expectedType: RawType,
                                       expression: Expression) -> Diagnostic {
    return Diagnostic(
      severity: .error, sourceLocation: expression.sourceLocation,
      message: "Cannot convert expression of type '\(actualType.name)' to expected " +
               "argument type '\(expectedType.name)'")
  }

  static func incompatibleCaseValueType(actualType: RawType,
                                        expectedType: RawType,
                                        expression: Expression) -> Diagnostic {
    return Diagnostic(
      severity: .error, sourceLocation: expression.sourceLocation,
      message: "Cannot convert expression of type '\(actualType.name)' to expected hidden type '\(expectedType.name)'")
  }

  static func incompatibleSubscript(actualType: RawType, expression: Expression) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: expression.sourceLocation,
                      message: "Cannot subscript expression of type '\(actualType.name)'")
  }

  static func incompatibleSubscriptIndex(actualType: RawType,
                                         expectedType: RawType,
                                         expression: Expression) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: expression.sourceLocation,
                      message: "Cannot convert expression of type '\(actualType.name)' to expected " +
                               "subscript type '\(expectedType.name)'")
  }

  static func gasParameterWithWrongType(_ gasParameter: FunctionArgument) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: gasParameter.sourceLocation,
      message: "'gas' hyper-parameter of an external call must be of type Int")
  }

  static func valueParameterWithWrongType(_ valueParameter: FunctionArgument) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: valueParameter.sourceLocation,
      message: "'value' hyper-parameter of an external call must be of type Wei")
  }
}
