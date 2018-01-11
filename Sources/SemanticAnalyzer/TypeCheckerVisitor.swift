//
//  TypeCheckerVisitor.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 1/11/18.
//

import AST
import Diagnostic

final class TypeCheckerVisitor: DiagnosticsTracking {
  var context: Context
  var diagnostics = [Diagnostic]()

  init(context: Context) {
    self.context = context
  }

  func visit(_ topLevelModule: TopLevelModule) {
    for declaration in topLevelModule.declarations {
      visit(declaration)
    }
  }

  func visit(_ topLevelDeclaration: TopLevelDeclaration) {
    switch topLevelDeclaration {
    case .contractDeclaration(let contractDeclaration):
      visit(contractDeclaration)
    case .contractBehaviorDeclaration(let contractBehaviorDeclaration):
      visit(contractBehaviorDeclaration)
    }
  }

  func visit(_ contractDeclaration: ContractDeclaration) {
    for variableDeclaration in contractDeclaration.variableDeclarations {
      visit(variableDeclaration)
    }
  }

  func visit(_ contractBehaviorDeclaration: ContractBehaviorDeclaration) {
    visit(contractBehaviorDeclaration.contractIdentifier)

    guard context.declaredContractsIdentifiers.contains(contractBehaviorDeclaration.contractIdentifier) else {
      addDiagnostic(.contractBehaviorDeclarationNoMatchingContract(contractBehaviorDeclaration))
      return
    }

    for callerCapability in contractBehaviorDeclaration.callerCapabilities {
      visit(callerCapability)
    }

    for functionDeclaration in contractBehaviorDeclaration.functionDeclarations {
      visit(functionDeclaration)
    }
  }

  func visit(_ variableDeclaration: VariableDeclaration) {
    visit(variableDeclaration.identifier)
    visit(variableDeclaration.type)
  }

  func visit(_ functionDeclaration: FunctionDeclaration) {
    visit(functionDeclaration.identifier)
    for parameter in functionDeclaration.parameters {
      visit(parameter)
    }

    if let resultType = functionDeclaration.resultType {
      visit(resultType)
    }

    visitBody(functionDeclaration.body, depth: 0)
  }

  func visit(_ parameter: Parameter) {}

  func visit(_ typeAnnotation: TypeAnnotation) {}

  func visit(_ identifier: Identifier) {}

  func visit(_ type: Type) {}

  func visit(_ callerCapability: CallerCapability) {
  }

  func visit(_ expression: Expression) {
    switch expression {
    case .binaryExpression(let binaryExpression): visit(binaryExpression)
    case .bracketedExpression(let expression): visit(expression)
    case .functionCall(let functionCall): visit(functionCall)
    case .identifier(let identifier): visit(identifier)
    case .literal(_): break
    case .self(_): break
    case .variableDeclaration(let variableDeclaration): visit(variableDeclaration)
    case .subscriptExpression(let subscriptExpression): visit(subscriptExpression)
    }
  }

  func visitBody(_ statements: [Statement], depth: Int) {
    let returnStatementIndex = statements.index(where: { statement in
      if case .returnStatement(_) = statement { return true }
      return false
    })

    if let returnStatementIndex = returnStatementIndex {
      if returnStatementIndex != statements.count - 1 {
        let nextStatement = statements[returnStatementIndex + 1]
        addDiagnostic(.codeAfterReturn(nextStatement))
      }
    }

    for statement in statements {
      visit(statement, depth: depth + 1)
    }
  }

  func visit(_ statement: Statement, depth: Int) {
    switch statement {
    case .expression(let expression): visit(expression)
    case .ifStatement(let ifStatement): visit(ifStatement, depth: depth)
    case .returnStatement(let returnStatement):
      visit(returnStatement)
    }
  }

  func visit(_ binaryExpression: BinaryExpression) {
    if case .binaryOperator(.equal) = binaryExpression.op.kind {
      visit(binaryExpression.lhs)
    }

    visit(binaryExpression.lhs)
    visit(binaryExpression.rhs)
  }

  func visit(_ functionCall: FunctionCall) {
    for argument in functionCall.arguments {
      visit(argument)
    }
  }

  func visit(_ subscriptExpression: SubscriptExpression) {
    visit(subscriptExpression.baseIdentifier)
    visit(subscriptExpression.indexExpression)
  }

  func visit(_ returnStatement: ReturnStatement) {}

  func visit(_ ifStatement: IfStatement, depth: Int) {
    visitBody(ifStatement.body, depth: depth + 1)
  }
}
