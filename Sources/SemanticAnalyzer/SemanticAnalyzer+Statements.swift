//
//  SemanticAnalyzer+Statements.swift
//  SemanticAnalyzer
//
//  Created by Farcas, Calin on 10/11/2018.
//
import Foundation
import AST
import Lexer
import Diagnostic

extension SemanticAnalyzer {
  public func postProcess(ifStatement: IfStatement,
                          passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    let ifStatement = ifStatement
    let condition = ifStatement.condition
    let environment = passContext.environment!
    let enclosingTypeIdentifier = passContext.enclosingTypeIdentifier!
    let typeStates = passContext.contractBehaviorDeclarationContext?.typeStates ?? []
    let callerProtections = passContext.contractBehaviorDeclarationContext?.callerProtections ?? []
    var diagnostics = [Diagnostic]()

    // Allow let statements
    switch condition {
    case .binaryExpression(let binaryExpression):
      let lhs = binaryExpression.lhs
      if case let .variableDeclaration(variableDeclaration) = lhs {
        if !variableDeclaration.isConstant {
          diagnostics.append(.invalidConditionTypeInIfStatement(ifStatement))
        }
        return ASTPassResult(element: ifStatement, diagnostics: diagnostics, passContext: passContext)
      }
    default:
      break
    }

    let expressionType = environment.type(of: condition,
                                          enclosingType: enclosingTypeIdentifier.name,
                                          typeStates: typeStates,
                                          callerProtections: callerProtections,
                                          scopeContext: passContext.scopeContext!)

    // Check that expression inside If statement is a Bool
    if expressionType != .basicType(.bool) {
      diagnostics.append(.invalidConditionTypeInIfStatement(ifStatement))
    }

    return ASTPassResult(element: ifStatement, diagnostics: diagnostics, passContext: passContext)
  }

  public func postProcess(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    let passContext = passContext.withUpdates { $0.functionCallReceiverTrail = [] }
    return ASTPassResult(element: statement, diagnostics: [], passContext: passContext)
  }

  // TODO: disabled, check doesn't work for value-returning calls
  /*
  public func postProcess(doCatchStatement: DoCatchStatement,
                          passContext: ASTPassContext) -> ASTPassResult<DoCatchStatement> {
      var diagnostics = [Diagnostic]()

      if !doCatchStatement.containsExternalCall {
        // TODO: disabled, check doesn't work for value-returning calls
        //diagnostics.append(.doCatchStatementContainsNoExternalCall(doCatchStatement))
      }

      return ASTPassResult(element: doCatchStatement, diagnostics: diagnostics, passContext: passContext)
  }*/
}
