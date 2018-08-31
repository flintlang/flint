//
//  ParserError.swift
//  Parser
//
//  Created by Hails, Daniel R on 31/08/2018.
//

import Diagnostic
import Source

extension Diagnostic {
  static func leftBraceExpected(in node: String, at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected '{' for \(node)")
  }
  static func rightBraceExpected(in node: String, at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected '}' for \(node)")
  }

  // MARK: Attributes
  static func missingAttributeName(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected an attribute name")
  }

  // MARK: Declarations
  static func badTopLevelDeclaration(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected top level declaration")
  }
  static func badDeclaration(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected declaration")
  }

  // MARK: Operators
  static func expectedValidOperator(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected operator in an operator declaration")
  }

  // MARK: Contract
  static func missingContractName(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected a contract name")
  }
  // MARK: Struct
  static func missingStructName(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected a struct name")
  }

  // MARK: Enum
  static func missingTypeForRawValue(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected type for enum declaration")
  }
  static func expectedEnumDeclarationCaseMember(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected a 'case' member")
  }
  static func expectedCaseName(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected a case name for enum declaration")
  }
  static func missingEnumName(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected an enum name")
  }

  // MARK: Function
  static func unnamedParameter(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected a parameter name followed by ':'")
  }
  static func expectedParameterType(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected parameter type followeding ':'")
  }
  static func expectedParameterOpenParenthesis(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected '(' in parameter")
  }
  static func expectedParameterCloseParenthesis(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected ')' in parameter")
  }
  static func missingFunctionName(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected a function name")
  }

  // MARK: Expressions
  static func expectedIdentifierForInOutExpr(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected an identifier after '&'")
  }
  static func expectedCloseParenFuncCall(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected ')' to complete function-call expression")
  }
  static func expectedColonAfterArgumentLabel(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected ':' after argument label")
  }
  static func expectedExpr(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected expression")
  }
  static func expectedIdentifierAfterDot(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected identifier after '.'")
  }
  static func expectedCloseSquareDictionaryLiteral(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected ']' in dictionary literal expression")
  }
  static func expectedColonDictionaryLiteral(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected ':' in dictionary literal")
  }
  static func expectedCloseSquareArrayLiteral(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected ']' in array literal")
  }

  // MARK: Generics
  static func expectedRightChevron(in node: String, at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected '>' to complete \(node)")
  }
  static func expectedGenericsParameterName(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected an identifier to name generic parameter")
  }

  // MARK: Generics
  static func statementSameLine(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Statements must be separated by a new line ")
  }

  // MARK: Type
  static func expectedType(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected type")
  }
  static func expectedCloseSquareArrayType(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected ']' in array type")
  }
  static func expectedCloseSquareDictionaryType(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected ']' in dictionary type")
  }
}
