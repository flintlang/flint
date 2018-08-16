//
//  TypeError.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 1/11/18.
//

import AST

extension Diagnostic {
  static func incompatibleReturnType(actualType: Type.RawType, expectedType: Type.RawType, expression: Expression) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: expression.sourceLocation, message: "Cannot convert expression of type '\(actualType.name)' to expected return type '\(expectedType.name)'")
  }

  static func invalidState(falseState: Expression, contract: RawTypeIdentifier) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: falseState.sourceLocation, message: "State not defined for contract '\(contract)'")
  }

  static func incompatibleForIterableType(iterableType: Type.RawType, statement: Statement) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: statement.sourceLocation, message: "Invalid iterable type '\(iterableType.name)'")
  }

  static func incompatibleForVariableType(varType: Type.RawType, valueType: Type.RawType, statement: Statement) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: statement.sourceLocation, message: "Cannot convert variable of type '\(varType.name)' to expected iterable value type '\(valueType.name)'")
  }

  static func incompatibleAssignment(lhsType: Type.RawType, rhsType: Type.RawType, expression: Expression) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: expression.sourceLocation, message: "Incompatible assignment between values of type '\(lhsType.name)' and '\(rhsType.name)'")
  }

  static func incompatibleArgumentType(actualType: Type.RawType, expectedType: Type.RawType, expression: Expression) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: expression.sourceLocation, message: "Cannot convert expression of type '\(actualType.name)' to expected argument type '\(expectedType.name)'")
  }

  static func incompatibleCaseValueType(actualType: Type.RawType, expectedType: Type.RawType, expression: Expression) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: expression.sourceLocation, message: "Cannot convert expression of type '\(actualType.name)' to expected hidden type '\(expectedType.name)'")
  }

  static func incompatibleSubscript(actualType: Type.RawType, expression: Expression) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: expression.sourceLocation, message: "Cannot subscript expression of type '\(actualType.name)'")
  }

  static func incompatibleSubscriptIndex(actualType: Type.RawType, expectedType: Type.RawType, expression: Expression) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: expression.sourceLocation, message: "Cannot convert expression of type '\(actualType.name)' to expected subscript type '\(expectedType.name)'")
  }
}
