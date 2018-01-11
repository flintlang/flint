//
//  SemanticVisitor.swift
//  flintc
//
//  Created by Franklin Schrans on 1/4/18.
//

import AST
import Diagnostic

final class SemanticAnalyzerVisitor {
  var context: Context
  var diagnostics = [Diagnostic]()

  init(context: Context) {
    self.context = context
  }

  func addDiagnostic(_ diagnostic: Diagnostic) {
    diagnostics.append(diagnostic)
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

  struct ContractBehaviorDeclarationContext {
    var contractIdentifier: Identifier
    var contractProperties: [VariableDeclaration]
    var callerCapabilities: [CallerCapability]

    func isPropertyDeclared(_ name: String) -> Bool {
      return contractProperties.contains { $0.identifier.name == name }
    }
  }

  func visit(_ contractBehaviorDeclaration: ContractBehaviorDeclaration) {
    visit(contractBehaviorDeclaration.contractIdentifier)

    guard context.declaredContractsIdentifiers.contains(contractBehaviorDeclaration.contractIdentifier) else {
      addDiagnostic(.contractBehaviorDeclarationNoMatchingContract(contractBehaviorDeclaration))
      return
    }

    let properties = context.properties(declaredIn: contractBehaviorDeclaration.contractIdentifier)
    let declarationContext = ContractBehaviorDeclarationContext(contractIdentifier: contractBehaviorDeclaration.contractIdentifier, contractProperties: properties, callerCapabilities: contractBehaviorDeclaration.callerCapabilities)

    for callerCapability in contractBehaviorDeclaration.callerCapabilities {
      visit(callerCapability, contractBehaviorDeclarationContext: declarationContext)
    }

    for functionDeclaration in contractBehaviorDeclaration.functionDeclarations {
      visit(functionDeclaration, contractBehaviorDeclarationContext: declarationContext)
    }
  }

  func visit(_ variableDeclaration: VariableDeclaration) {
    visit(variableDeclaration.identifier)
    visit(variableDeclaration.type)
  }

  struct FunctionDeclarationContext {
    var declaration: FunctionDeclaration
    var contractContext: ContractBehaviorDeclarationContext

    var isMutating: Bool {
      return declaration.isMutating
    }
  }

  func visit(_ functionDeclaration: FunctionDeclaration, contractBehaviorDeclarationContext: ContractBehaviorDeclarationContext) {
    visit(functionDeclaration.identifier)
    for parameter in functionDeclaration.parameters {
      visit(parameter)
    }

    if let resultType = functionDeclaration.resultType {
      visit(resultType)
    }

    let functionDeclarationContext = FunctionDeclarationContext(declaration: functionDeclaration, contractContext: contractBehaviorDeclarationContext)
    visitBody(functionDeclaration.body, depth: 0, functionDeclarationContext: functionDeclarationContext)
  }

  func visit(_ parameter: Parameter) {}

  func visit(_ typeAnnotation: TypeAnnotation) {}

  func visit(_ identifier: Identifier, asLValue: Bool = false, functionDeclarationContext: FunctionDeclarationContext? = nil) {
    if let functionDeclarationContext = functionDeclarationContext, identifier.isPropertyAccess {
      if !functionDeclarationContext.contractContext.isPropertyDeclared(identifier.name) {
        addDiagnostic(.useOfUndeclaredIdentifier(identifier))
      }
      if asLValue, !functionDeclarationContext.isMutating {
        addDiagnostic(.useOfMutatingExpressionInNonMutatingFunction(.identifier(identifier), functionDeclaration: functionDeclarationContext.declaration))
      }
    }
}

  func visit(_ type: Type) {}

  func visit(_ callerCapability: CallerCapability, contractBehaviorDeclarationContext: ContractBehaviorDeclarationContext) {
    guard callerCapability.isAny || context.declaredCallerCapabilities(inContractWithIdentifier: contractBehaviorDeclarationContext.contractIdentifier).contains(where: { $0.identifier.name == callerCapability.name }) else {
      addDiagnostic(.undeclaredCallerCapability(callerCapability, contractIdentifier: contractBehaviorDeclarationContext.contractIdentifier))
      return
    }
  }

  func visit(_ expression: Expression, asLValue: Bool = false, functionDeclarationContext: FunctionDeclarationContext) {
    switch expression {
    case .binaryExpression(let binaryExpression): visit(binaryExpression, asLValue: asLValue, functionDeclarationContext: functionDeclarationContext)
    case .bracketedExpression(let expression): visit(expression, functionDeclarationContext: functionDeclarationContext)
    case .functionCall(let functionCall): visit(functionCall, functionDeclarationContext: functionDeclarationContext)
    case .identifier(let identifier): visit(identifier, asLValue: asLValue, functionDeclarationContext: functionDeclarationContext)
    case .literal(_): break
    case .self(_): break
    case .variableDeclaration(let variableDeclaration): visit(variableDeclaration)
    case .subscriptExpression(let subscriptExpression): visit(subscriptExpression, asLValue: asLValue, functionDeclarationContext: functionDeclarationContext)
    }
  }

  func visitBody(_ statements: [Statement], depth: Int, functionDeclarationContext: FunctionDeclarationContext) {
    let returnStatementIndex = statements.index(where: { statement in
      if case .returnStatement(_) = statement { return true }
      return false
    })

    if let returnStatementIndex = returnStatementIndex {
      if returnStatementIndex != statements.count - 1 {
        let nextStatement = statements[returnStatementIndex + 1]
        addDiagnostic(.codeAfterReturn(nextStatement))
      }

      if functionDeclarationContext.declaration.resultType == nil {
        addDiagnostic(.unexpectedReturnInVoidFunction(statements[returnStatementIndex]))
      }
    } else {
      if let resultType = functionDeclarationContext.declaration.resultType, depth == 0 {
        addDiagnostic(.missingReturnInNonVoidFunction(closeBraceToken: functionDeclarationContext.declaration.closeBraceToken, resultType: resultType))
      }
    }

    for statement in statements {
      visit(statement, depth: depth + 1, functionDeclarationContext: functionDeclarationContext)
    }
  }

  func visit(_ statement: Statement, depth: Int, functionDeclarationContext: FunctionDeclarationContext) {
    switch statement {
    case .expression(let expression): visit(expression, functionDeclarationContext: functionDeclarationContext)
    case .ifStatement(let ifStatement): visit(ifStatement, depth: depth, functionDeclarationContext: functionDeclarationContext)
    case .returnStatement(let returnStatement):
      visit(returnStatement, functionDeclarationContext: functionDeclarationContext)
    }
  }

  func visit(_ binaryExpression: BinaryExpression, asLValue: Bool, functionDeclarationContext: FunctionDeclarationContext) {
    if case .binaryOperator(.equal) = binaryExpression.op.kind {
      visit(binaryExpression.lhs, asLValue: true, functionDeclarationContext: functionDeclarationContext)
    }

    if case .self(_) = binaryExpression.lhs, asLValue, !functionDeclarationContext.isMutating {
      addDiagnostic(.useOfMutatingExpressionInNonMutatingFunction(.binaryExpression(binaryExpression), functionDeclaration: functionDeclarationContext.declaration))
      return
    }

    visit(binaryExpression.lhs, functionDeclarationContext: functionDeclarationContext)
    visit(binaryExpression.rhs, functionDeclarationContext: functionDeclarationContext)
  }

  func visit(_ functionCall: FunctionCall, functionDeclarationContext: FunctionDeclarationContext) {

    guard let matchingFunction = context.matchFunctionCall(functionCall, contractIdentifier: functionDeclarationContext.contractContext.contractIdentifier, callerCapabilities: functionDeclarationContext.contractContext.callerCapabilities) else {
      addDiagnostic(.noMatchingFunctionForFunctionCall(functionCall, contextCallerCapabilities: functionDeclarationContext.contractContext.callerCapabilities))
      return
    }

    if matchingFunction.isMutating, !functionDeclarationContext.isMutating {
      addDiagnostic(.useOfMutatingExpressionInNonMutatingFunction(.functionCall(functionCall), functionDeclaration: functionDeclarationContext.declaration))
    }

    for argument in functionCall.arguments {
      visit(argument, functionDeclarationContext: functionDeclarationContext)
    }
  }

  func visit(_ subscriptExpression: SubscriptExpression, asLValue: Bool, functionDeclarationContext: FunctionDeclarationContext) {
    visit(subscriptExpression.baseIdentifier, asLValue: asLValue, functionDeclarationContext: functionDeclarationContext)
    visit(subscriptExpression.indexExpression, asLValue: asLValue, functionDeclarationContext: functionDeclarationContext)
  }

  func visit(_ returnStatement: ReturnStatement, functionDeclarationContext: FunctionDeclarationContext) {}

  func visit(_ ifStatement: IfStatement, depth: Int, functionDeclarationContext: FunctionDeclarationContext) {
    visitBody(ifStatement.body, depth: depth + 1, functionDeclarationContext: functionDeclarationContext)
  }
}
