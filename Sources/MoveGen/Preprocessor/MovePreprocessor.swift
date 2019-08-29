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

  public func postProcess(returnStatement: ReturnStatement,
                          passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    var passContext = passContext
    var returnStatement = returnStatement
    returnStatement.cleanupStatements = passContext.postStatements
    passContext.postStatements = []  // No post-statements after a return statement, it maketh no sense
    return ASTPassResult(element: returnStatement, diagnostics: [], passContext: passContext)
  }

  public func process(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    var statement = statement
    var passContext = passContext
    if case .expression(let expression) = statement {
      var functionCall = expression
      if case .binaryExpression(let binaryExpression) = expression,
         case .punctuation(.dot) = binaryExpression.op.kind {
        functionCall = binaryExpression.rhs
      }
      if case .functionCall(let call) = functionCall,
         let environment = passContext.environment,
         case .matchedFunction(let function) = environment.matchFunctionCall(
             call,
             enclosingType: passContext.enclosingTypeIdentifier?.name ?? "",
             typeStates: passContext.contractBehaviorDeclarationContext?.typeStates ?? [],
             callerProtections: passContext.contractBehaviorDeclarationContext?.callerProtections ?? [],
             scopeContext: passContext.scopeContext!),
         .basicType(.void) != function.resultType {
        statement = Move.release(expression: expression, type: function.resultType)
      }
    }
    return ASTPassResult(element: statement, diagnostics: [], passContext: passContext)
  }

  public func postProcess(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    let passContext = passContext.withUpdates { $0.functionCallReceiverTrail = [] }
    return ASTPassResult(element: statement, diagnostics: [], passContext: passContext)
  }
}

extension ASTPass {
  public func preAssign(_ element: Expression,
                        passContext: inout ASTPassContext,
                        borrowLocal: Bool = false,
                        isReference: Bool = true) -> Expression {
    guard let environment = passContext.environment,
          var scopeContext = passContext.scopeContext,
          let enclosingType = passContext.enclosingTypeIdentifier?.name else {
      print("Cannot infer type for \(element.sourceLocation)")
      exit(1)
    }

    let type = environment.type(of: element,
                                enclosingType: enclosingType,
                                scopeContext: scopeContext)

    let expression: Expression
    if borrowLocal || type.isBuiltInType || !isReference {
      expression = element
    } else {
      expression = .inoutExpression(InoutExpression(
          ampersandToken: Token(kind: .punctuation(.ampersand),
                                sourceLocation: element.sourceLocation),
          expression: element
      ))
    }

    let temporaryId: Identifier
    // Check if this expression's already been assigned
    if let statement: Statement = passContext.preStatements.first(where: { (statement: Statement) in
      if case .expression(.binaryExpression(let binary)) = statement,
         binary.opToken == .equal,
         case .identifier = binary.lhs {
        return binary.rhs == expression
      }
      return false
    }) {
      guard case .expression(.binaryExpression(let binary)) = statement,
            case .identifier(let identifier) = binary.lhs else {
        fatalError("Cannot find expected identifier for `\(element)`")
      }
      temporaryId = identifier
    } else {
      // Otherwise create a new identifier and handle set-up and clean up
      temporaryId = scopeContext.freshIdentifier(sourceLocation: element.sourceLocation)
      let declaration: VariableDeclaration
      if type.isBuiltInType || borrowLocal {
        declaration = VariableDeclaration(identifier: temporaryId,
                                          type: Type(inferredType: type,
                                                     identifier: temporaryId))
      } else {
        declaration = VariableDeclaration(identifier: temporaryId,
                                          type: Type(inferredType: .inoutType(type),
                                                     identifier: temporaryId))
        passContext.postStatements.append(Move.release(expression: .identifier(temporaryId),
                                                       type: .inoutType(type)))
      }

      passContext.preStatements.append(Statement.expression(.binaryExpression(BinaryExpression(
          lhs: .identifier(temporaryId),
          op: Token(kind: .punctuation(.equal), sourceLocation: element.sourceLocation),
          rhs: expression
      ))))
      passContext.blockContext?.scopeContext.localVariables.append(declaration)
      passContext.functionDeclarationContext?.innerDeclarations.append(declaration)
      passContext.specialDeclarationContext?.innerDeclarations.append(declaration)
      passContext.functionDeclarationContext?.declaration.scopeContext?.localVariables.append(declaration)
      passContext.specialDeclarationContext?.declaration.scopeContext.localVariables.append(declaration)
      scopeContext.localVariables.append(declaration)
    }

    passContext.scopeContext = scopeContext

    if borrowLocal {
      return .inoutExpression(InoutExpression(
          ampersandToken: Token(kind: .punctuation(.and),
                                sourceLocation: element.sourceLocation),
          expression: .identifier(temporaryId)
      ))
    }
    return .identifier(temporaryId)
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
