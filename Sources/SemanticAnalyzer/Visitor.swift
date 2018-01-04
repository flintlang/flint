//
//  Visitor.swift
//  etherlang
//
//  Created by Franklin Schrans on 1/4/18.
//

import AST

extension SemanticAnalyzer {
  func visit(_ topLevelModule: TopLevelModule) throws {
    for declaration in topLevelModule.declarations {
      try visit(declaration)
    }
  }

  func visit(_ topLevelDeclaration: TopLevelDeclaration) throws {
    switch topLevelDeclaration {
    case .contractDeclaration(let contractDeclaration):
      try visit(contractDeclaration)
    case .contractBehaviorDeclaration(let contractBehaviorDeclaration):
      try visit(contractBehaviorDeclaration)
    }
  }

  func visit(_ contractDeclaration: ContractDeclaration) throws {
    for variableDeclaration in contractDeclaration.variableDeclarations {
      try visit(variableDeclaration)
    }
  }

  func visit(_ contractBehaviorDeclaration: ContractBehaviorDeclaration) throws {
    try visit(contractBehaviorDeclaration.contractIdentifier)

    guard context.declaredContractsIdentifiers.contains(contractBehaviorDeclaration.contractIdentifier) else {
      throw SemanticError.contractBehaviorDeclarationNoMatchingContract(contractBehaviorDeclaration)
    }

    for callerCapability in contractBehaviorDeclaration.callerCapabilities {
      try visit(callerCapability)
    }


    let declarationContext = FunctionDeclarationContext(contractIdentifier: contractBehaviorDeclaration.contractIdentifier, callerCapabilities: contractBehaviorDeclaration.callerCapabilities)

    for functionDeclaration in contractBehaviorDeclaration.functionDeclarations {
      try visit(functionDeclaration, functionDeclarationContext: declarationContext)
    }
  }

  func visit(_ variableDeclaration: VariableDeclaration) throws {
    try visit(variableDeclaration.identifier)
    try visit(variableDeclaration.type)
  }

  struct FunctionDeclarationContext {
    var contractIdentifier: Identifier
    var callerCapabilities: [CallerCapability]
  }

  func visit(_ functionDeclaration: FunctionDeclaration, functionDeclarationContext: FunctionDeclarationContext) throws {
    try visit(functionDeclaration.identifier)
    for parameter in functionDeclaration.parameters {
      try visit(parameter)
    }

    if let resultType = functionDeclaration.resultType {
      try visit(resultType)
    }

    for statement in functionDeclaration.body {
      try visit(statement, functionDeclarationContext: functionDeclarationContext)
    }
  }

  func visit(_ parameter: Parameter) throws {}

  func visit(_ typeAnnotation: TypeAnnotation) throws {}

  func visit(_ identifier: Identifier) throws {}

  func visit(_ type: Type) throws {}

  func visit(_ callerCapability: CallerCapability) throws {}

  func visit(_ expression: Expression, functionDeclarationContext: FunctionDeclarationContext) throws {
    switch expression {
    case .binaryExpression(let binaryExpression): try visit(binaryExpression, functionDeclarationContext: functionDeclarationContext)
    case .bracketedExpression(let expression): try visit(expression, functionDeclarationContext: functionDeclarationContext)
    case .functionCall(let functionCall): try visit(functionCall, functionDeclarationContext: functionDeclarationContext)
    case .identifier(let identifier): try visit(identifier)
    case .literal(_): break
    case .variableDeclaration(let variableDeclaration): try visit(variableDeclaration)
    }
  }

  func visit(_ statement: Statement, functionDeclarationContext: FunctionDeclarationContext) throws {
    switch statement {
    case .expression(let expression): try visit(expression, functionDeclarationContext: functionDeclarationContext)
    case .ifStatement(let ifStatement): try visit(ifStatement, functionDeclarationContext: functionDeclarationContext)
    case .returnStatement(let returnStatement): try visit(returnStatement, functionDeclarationContext: functionDeclarationContext)
    }
  }

  func visit(_ binaryExpression: BinaryExpression, functionDeclarationContext: FunctionDeclarationContext) throws {
    try visit(binaryExpression.lhs, functionDeclarationContext: functionDeclarationContext)
    try visit(binaryExpression.rhs, functionDeclarationContext: functionDeclarationContext)
  }

  func visit(_ functionCall: FunctionCall, functionDeclarationContext: FunctionDeclarationContext) throws {

    guard let _ = context.matchFunctionCall(functionCall, contractIdentifier: functionDeclarationContext.contractIdentifier, callerCapabilities: functionDeclarationContext.callerCapabilities) else {
      throw SemanticError.noMatchingFunctionForFunctionCall(functionCall, contextCapabilities: functionDeclarationContext.callerCapabilities)
    }
  }

  func visit(_ returnStatement: ReturnStatement, functionDeclarationContext: FunctionDeclarationContext) throws {}

  func visit(_ ifStatement: IfStatement, functionDeclarationContext: FunctionDeclarationContext) throws {}
}
