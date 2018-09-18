//
//  ParserError.swift
//  Parser
//
//  Created by Hails, Daniel R on 31/08/2018.
//

import Diagnostic
import Source

extension Diagnostic {
  static func dummy() -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: .DUMMY, message: "Internal Error has occured")
  }

  static func leftBraceExpected(in node: String, at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected '{' for \(node)")
  }
  static func rightBraceExpected(in node: String, at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected '}' for \(node)")
  }

  static func unexpectedEOF() -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: .DUMMY, message: "Unexpected end of file")
  }

  // MARK: Attributes
  static func missingAttributeName(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected an attribute name")
  }

  // MARK: Modifiers
  static func expectedModifier(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected a modifier")
  }

  // MARK: Declarations
  static func badTopLevelDeclaration(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected top level declaration")
  }
  static func badDeclaration(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected declaration")
  }
  static func badMember(in node: String, at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected valid member of \(node)")
  }

  // MARK: Operators
  static func expectedValidOperator(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected operator in binary expression")
  }

  // MARK: Contract
  static func expectedBehaviourSeparator(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected behaviour separator")
  }

  // MARK: Statement
  static func expectedStatement(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected statement")
  }
  static func expectedForInStatement(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected 'in' between variable declaration and iterable")
  }
  static func statementSameLine(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Statements must be separated by a new line ")
  }

  // MARK: Components
  static func expectedIdentifier(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected identifier")
  }
  static func expectedAttribute(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected '@' declared attribute")
  }
  static func expectedLiteral(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected literal")
  }
  static func expectedLeftArrow(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected '<-'")
  }
  static func expectedRightArrow(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected '->'")
  }
  static func expectedTypeAnnotation(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected type annotation")
  }
  static func expectedConformance(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected a trait identifier to conform to")
  }

  // MARK: Enum
  static func expectedEnumDeclarationCaseMember(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected a 'case' member")
  }

  // MARK: Function
  static func expectedParameterOpenParenthesis(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected '(' in parameter")
  }
  static func expectedParameterCloseParenthesis(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected ')' in parameter")
  }

  // MARK: Expressions
  static func expectedCloseParen(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected ')' for bracketed expression")
  }
  static func expectedColonAfterArgumentLabel(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected ':' after argument label")
  }
  static func expectedExpr(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected expression")
  }
  static func expectedSort(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected the try to be specified with '!' or '?'")
  }
  static func expectedRangeOperator(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected '...' or '..<' for setting range type")
  }
  static func expectedCloseSquareSubscript(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected ']' in subscript expression")
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
  static func expectedSeparator(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected ',' in list")
  }
  static func expectedEndAfterInout(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected ',' or ')' after inout identifier")
  }
  
  // MARK: Generics
  static func expectedRightChevron(in node: String, at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected '>' to complete \(node)")
  }

  // MARK: Type
  static func expectedType(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected type")
  }
  static func expectedCloseSquareArrayType(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected ']' in array type")
  }
  static func expectedIntegerInFixedArrayType(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation, message: "Expected an integer in fixed array type")
  }
}
