//
//  Visitor.swift
//  etherlang
//
//  Created by Franklin Schrans on 1/4/18.
//

import AST

extension SemanticAnalyzer {
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
    var callerCapabilities: [CallerCapability]
  }

  func visit(_ contractBehaviorDeclaration: ContractBehaviorDeclaration) {
    visit(contractBehaviorDeclaration.contractIdentifier)

    guard context.declaredContractsIdentifiers.contains(contractBehaviorDeclaration.contractIdentifier) else {
      addDiagnostic(.contractBehaviorDeclarationNoMatchingContract(contractBehaviorDeclaration))
      return
    }

    let declarationContext = ContractBehaviorDeclarationContext(contractIdentifier: contractBehaviorDeclaration.contractIdentifier, callerCapabilities: contractBehaviorDeclaration.callerCapabilities)

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

  func visit(_ functionDeclaration: FunctionDeclaration, contractBehaviorDeclarationContext: ContractBehaviorDeclarationContext) {
    visit(functionDeclaration.identifier)
    for parameter in functionDeclaration.parameters {
      visit(parameter)
    }

    if let resultType = functionDeclaration.resultType {
      visit(resultType)
    }

    for statement in functionDeclaration.body {
      visit(statement, contractBehaviorDeclarationContext: contractBehaviorDeclarationContext)
    }
  }

  func visit(_ parameter: Parameter) {}

  func visit(_ typeAnnotation: TypeAnnotation) {}

  func visit(_ identifier: Identifier) {}

  func visit(_ type: Type) {}

  func visit(_ callerCapability: CallerCapability, contractBehaviorDeclarationContext: ContractBehaviorDeclarationContext) {
    guard callerCapability.name == "any" || context.declaredCallerCapabilities(inContractWithIdentifier: contractBehaviorDeclarationContext.contractIdentifier).contains(where: { $0.identifier.name == callerCapability.name }) else {
      addDiagnostic(.undeclaredCallerCapability(callerCapability, contractIdentifier: contractBehaviorDeclarationContext.contractIdentifier))
      return
    }
  }

  func visit(_ expression: Expression, contractBehaviorDeclarationContext: ContractBehaviorDeclarationContext) {
    switch expression {
    case .binaryExpression(let binaryExpression): visit(binaryExpression, contractBehaviorDeclarationContext: contractBehaviorDeclarationContext)
    case .bracketedExpression(let expression): visit(expression, contractBehaviorDeclarationContext: contractBehaviorDeclarationContext)
    case .functionCall(let functionCall): visit(functionCall, contractBehaviorDeclarationContext: contractBehaviorDeclarationContext)
    case .identifier(let identifier): visit(identifier)
    case .literal(_): break
    case .self(_): break
    case .variableDeclaration(let variableDeclaration): visit(variableDeclaration)
    }
  }

  func visit(_ statement: Statement, contractBehaviorDeclarationContext: ContractBehaviorDeclarationContext) {
    switch statement {
    case .expression(let expression): visit(expression, contractBehaviorDeclarationContext: contractBehaviorDeclarationContext)
    case .ifStatement(let ifStatement): visit(ifStatement, contractBehaviorDeclarationContext: contractBehaviorDeclarationContext)
    case .returnStatement(let returnStatement): visit(returnStatement, contractBehaviorDeclarationContext: contractBehaviorDeclarationContext)
    }
  }

  func visit(_ binaryExpression: BinaryExpression, contractBehaviorDeclarationContext: ContractBehaviorDeclarationContext) {
    visit(binaryExpression.lhs, contractBehaviorDeclarationContext: contractBehaviorDeclarationContext)
    visit(binaryExpression.rhs, contractBehaviorDeclarationContext: contractBehaviorDeclarationContext)
  }

  func visit(_ functionCall: FunctionCall, contractBehaviorDeclarationContext: ContractBehaviorDeclarationContext) {

    guard let _ = context.matchFunctionCall(functionCall, contractIdentifier: contractBehaviorDeclarationContext.contractIdentifier, callerCapabilities: contractBehaviorDeclarationContext.callerCapabilities) else {
      addDiagnostic(.noMatchingFunctionForFunctionCall(functionCall, contextCallerCapabilities: contractBehaviorDeclarationContext.callerCapabilities))
      return
    }

    for argument in functionCall.arguments {
      visit(argument, contractBehaviorDeclarationContext: contractBehaviorDeclarationContext)
    }
  }

  func visit(_ returnStatement: ReturnStatement, contractBehaviorDeclarationContext: ContractBehaviorDeclarationContext) {}

  func visit(_ ifStatement: IfStatement, contractBehaviorDeclarationContext: ContractBehaviorDeclarationContext) {}
}
