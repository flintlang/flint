//
//  MovePreprocessor.swift
//  MoveGen
//
//  Created by Franklin Schrans on 2/1/18.
//

import AST

import Foundation
import Source
import Lexer

/// A preprocessing step to update the program's AST before code generation.
public struct MovePreprocessor: ASTPass {

  public init() {}

  /// Returns assignment statements for all the properties which have been assigned default values.
  func defaultValueAssignments(in passContext: ASTPassContext) -> [Statement] {
    let enclosingType = passContext.enclosingTypeIdentifier!.name
    let propertiesInEnclosingType = passContext.environment!.propertyDeclarations(in: enclosingType)

    return propertiesInEnclosingType.compactMap { declaration -> Statement? in
      guard let assignedExpression = declaration.value else { return nil }

      var identifier = declaration.identifier
      identifier.enclosingType = enclosingType

      return .expression(
          .binaryExpression(
              BinaryExpression(lhs: .identifier(identifier),
                               op: Token(kind: .punctuation(.equal), sourceLocation: identifier.sourceLocation),
                               rhs: assignedExpression)))
    }
  }

  func constructParameter(name: String, type: RawType, sourceLocation: SourceLocation) -> Parameter {
    let identifier = Identifier(identifierToken: Token(kind: .identifier(name), sourceLocation: sourceLocation))
    return Parameter(identifier: identifier,
                     type: Type(inferredType: type,
                                identifier: identifier),
                     implicitToken: nil,
                     assignedExpression: nil)
  }

  func constructThisParameter(type: RawType, sourceLocation: SourceLocation) -> Parameter {
    let identifier = Identifier(identifierToken: Token(kind: .`self`, sourceLocation: sourceLocation))
    return Parameter(identifier: identifier,
                     type: Type(inferredType: type,
                                identifier: identifier),
                     implicitToken: nil,
                     assignedExpression: nil)
  }

  // MARK: Statement
  public func process(becomeStatement: BecomeStatement, passContext: ASTPassContext) -> ASTPassResult<BecomeStatement> {
    var becomeStatement = becomeStatement

    let enumName = ContractDeclaration.contractEnumPrefix + passContext.enclosingTypeIdentifier!.name
    let enumReference: Expression = .identifier(
        Identifier(identifierToken: Token(kind: .identifier(enumName), sourceLocation: becomeStatement.sourceLocation)))
    let state = becomeStatement.expression.assigningEnclosingType(type: enumName)

    let dot = Token(kind: .punctuation(.dot), sourceLocation: becomeStatement.sourceLocation)

    becomeStatement.expression = .binaryExpression(BinaryExpression(lhs: enumReference, op: dot, rhs: state))

    return ASTPassResult(element: becomeStatement, diagnostics: [], passContext: passContext)
  }

  public func postProcess(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    let passContext = passContext.withUpdates { $0.functionCallReceiverTrail = [] }
    return ASTPassResult(element: statement, diagnostics: [], passContext: passContext)
  }
}

extension ASTPassContext {
  var functionCallReceiverTrail: [Expression]? {
    get { return self[FunctionCallReceiverTrailContextEntry.self] }
    set { self[FunctionCallReceiverTrailContextEntry.self] = newValue }
  }
}

struct FunctionCallReceiverTrailContextEntry: PassContextEntry {
  typealias Value = [Expression]
}
