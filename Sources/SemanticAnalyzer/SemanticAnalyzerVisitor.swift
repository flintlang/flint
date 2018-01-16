//
//  SemanticAnalyzerVisitor.swift
//  flintc
//
//  Created by Franklin Schrans on 1/4/18.
//

import AST

final class SemanticAnalyzerVisitor: DiagnosticsTracking {
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

    let properties = context.properties(declaredIn: contractBehaviorDeclaration.contractIdentifier)
    let declarationContext = ContractBehaviorDeclarationContext(contractIdentifier: contractBehaviorDeclaration.contractIdentifier, contractProperties: properties, callerCapabilities: contractBehaviorDeclaration.callerCapabilities)

    for callerCapability in contractBehaviorDeclaration.callerCapabilities {
      visit(callerCapability, contractBehaviorDeclarationContext: declarationContext)
    }

    for functionDeclaration in contractBehaviorDeclaration.functionDeclarations {
      visit(functionDeclaration, contractBehaviorDeclarationContext: declarationContext)
    }
  }

  @discardableResult
  func visit(_ variableDeclaration: VariableDeclaration) -> BodyVisitResult {
    visit(variableDeclaration.identifier)
    visit(variableDeclaration.type)
    return BodyVisitResult(mutatingExpressions: [])
  }

  func visit(_ functionDeclaration: FunctionDeclaration, contractBehaviorDeclarationContext: ContractBehaviorDeclarationContext) {
    let functionDeclarationContext = FunctionDeclarationContext(declaration: functionDeclaration, contractContext: contractBehaviorDeclarationContext)

    visit(functionDeclaration.identifier)

    for parameter in functionDeclaration.parameters {
      visit(parameter)
    }

    if functionDeclaration.isPayable {
      let payableValueParameters = functionDeclaration.parameters.filter { $0.isPayableValueParameter }
      if payableValueParameters.count > 1 {
        addDiagnostic(.ambiguousPayableValueParameter(functionDeclaration))
      } else if payableValueParameters.count == 0 {
        addDiagnostic(.payableFunctionDoesNotHavePayableValueParameter(functionDeclaration))
      }
    }

    if let resultType = functionDeclaration.resultType {
      visit(resultType)
    }

    let bodyVisitResult = visitBody(functionDeclaration.body, depth: 0, functionDeclarationContext: functionDeclarationContext)

    if functionDeclarationContext.isMutating, bodyVisitResult.mutatingExpressions.isEmpty {
      addDiagnostic(.functionCanBeDeclaredNonMutating(functionDeclaration.mutatingToken))
    }
  }

  func visit(_ parameter: Parameter) {}

  func visit(_ typeAnnotation: TypeAnnotation) {}

  @discardableResult
  func visit(_ identifier: Identifier, asLValue: Bool = false, functionDeclarationContext: FunctionDeclarationContext? = nil) -> BodyVisitResult {
    if let functionDeclarationContext = functionDeclarationContext, identifier.isPropertyAccess {
      if !functionDeclarationContext.contractContext.isPropertyDeclared(identifier.name) {
        addDiagnostic(.useOfUndeclaredIdentifier(identifier))
        context.addUsedUndefinedVariable(identifier, contractIdentifier: functionDeclarationContext.contractContext.contractIdentifier)
      }
      if asLValue {
        if !functionDeclarationContext.isMutating {
          addDiagnostic(.useOfMutatingExpressionInNonMutatingFunction(.identifier(identifier), functionDeclaration: functionDeclarationContext.declaration))
        }
        return BodyVisitResult(mutatingExpressions: [.identifier(identifier)])
      }
    }

    return BodyVisitResult(mutatingExpressions: [])
  }

  func visit(_ type: Type) {}

  func visit(_ callerCapability: CallerCapability, contractBehaviorDeclarationContext: ContractBehaviorDeclarationContext) {
    guard callerCapability.isAny || context.containsCallerCapability(callerCapability, in: contractBehaviorDeclarationContext.contractIdentifier) else {
      addDiagnostic(.undeclaredCallerCapability(callerCapability, contractIdentifier: contractBehaviorDeclarationContext.contractIdentifier))
      return
    }
  }

  func visit(_ expression: Expression, asLValue: Bool = false, functionDeclarationContext: FunctionDeclarationContext) -> BodyVisitResult {
    switch expression {
    case .binaryExpression(let binaryExpression): return visit(binaryExpression, asLValue: asLValue, functionDeclarationContext: functionDeclarationContext)
    case .bracketedExpression(let expression): return visit(expression, functionDeclarationContext: functionDeclarationContext)
    case .functionCall(let functionCall): return visit(functionCall, functionDeclarationContext: functionDeclarationContext)
    case .identifier(let identifier): return visit(identifier, asLValue: asLValue, functionDeclarationContext: functionDeclarationContext)
    case .literal(_): break
    case .self(_): break
    case .variableDeclaration(let variableDeclaration): return visit(variableDeclaration)
    case .subscriptExpression(let subscriptExpression): return visit(subscriptExpression, asLValue: asLValue, functionDeclarationContext: functionDeclarationContext)
    }

    return BodyVisitResult(mutatingExpressions: [])
  }

  struct BodyVisitResult {
    var mutatingExpressions = [Expression]()
  }

  func visitBody(_ statements: [Statement], depth: Int, functionDeclarationContext: FunctionDeclarationContext) -> BodyVisitResult {
    let returnStatementIndex = statements.index(where: { statement in
      if case .returnStatement(_) = statement { return true }
      return false
    })

    if let returnStatementIndex = returnStatementIndex {
      if returnStatementIndex != statements.count - 1 {
        let nextStatement = statements[returnStatementIndex + 1]
        addDiagnostic(.codeAfterReturn(nextStatement))
      }
    } else {
      if let resultType = functionDeclarationContext.declaration.resultType, depth == 0 {
        addDiagnostic(.missingReturnInNonVoidFunction(closeBraceToken: functionDeclarationContext.declaration.closeBraceToken, resultType: resultType))
      }
    }

    var mutatingExpressions = [Expression]()

    for statement in statements {
      let statementVisitResult = visit(statement, depth: depth + 1, functionDeclarationContext: functionDeclarationContext)
      mutatingExpressions.append(contentsOf: statementVisitResult.mutatingExpressions)
    }

    return BodyVisitResult(mutatingExpressions: mutatingExpressions)
  }

  func visit(_ statement: Statement, depth: Int, functionDeclarationContext: FunctionDeclarationContext) -> BodyVisitResult {
    switch statement {
    case .expression(let expression):
      return visit(expression, functionDeclarationContext: functionDeclarationContext)
    case .ifStatement(let ifStatement):
      return visit(ifStatement, depth: depth, functionDeclarationContext: functionDeclarationContext)
    case .returnStatement(let returnStatement):
      return visit(returnStatement, functionDeclarationContext: functionDeclarationContext)
    }
  }

  func visit(_ binaryExpression: BinaryExpression, asLValue: Bool, functionDeclarationContext: FunctionDeclarationContext) -> BodyVisitResult {
    var mutatingExpressions = [Expression]()
    if case .punctuation(.equal) = binaryExpression.op.kind {
      let result = visit(binaryExpression.lhs, asLValue: true, functionDeclarationContext: functionDeclarationContext)
      mutatingExpressions.append(contentsOf: result.mutatingExpressions)
    }

    if case .self(_) = binaryExpression.lhs, asLValue, !functionDeclarationContext.isMutating {
      addDiagnostic(.useOfMutatingExpressionInNonMutatingFunction(.binaryExpression(binaryExpression), functionDeclaration: functionDeclarationContext.declaration))
      mutatingExpressions.append(.binaryExpression(binaryExpression))
    }

    let lhsResult = visit(binaryExpression.lhs, functionDeclarationContext: functionDeclarationContext)
    let rhsResult = visit(binaryExpression.rhs, functionDeclarationContext: functionDeclarationContext)
    mutatingExpressions.append(contentsOf: lhsResult.mutatingExpressions)
    mutatingExpressions.append(contentsOf: rhsResult.mutatingExpressions)

    return BodyVisitResult(mutatingExpressions: mutatingExpressions)
  }

  func visit(_ functionCall: FunctionCall, functionDeclarationContext: FunctionDeclarationContext) -> BodyVisitResult {
    var mutatingExpressions = [Expression]()
    let contractIdentifier = functionDeclarationContext.contractContext.contractIdentifier

    if let matchingFunction = context.matchFunctionCall(functionCall, contractIdentifier: functionDeclarationContext.contractContext.contractIdentifier, callerCapabilities: functionDeclarationContext.contractContext.callerCapabilities) {
      if matchingFunction.isMutating {
        mutatingExpressions.append(.functionCall(functionCall))

        if !functionDeclarationContext.isMutating {
          addDiagnostic(.useOfMutatingExpressionInNonMutatingFunction(.functionCall(functionCall), functionDeclaration: functionDeclarationContext.declaration))
        }
      }
    } else if let _ = context.matchEventCall(functionCall, contractIdentifier: contractIdentifier) {
    } else {
      addDiagnostic(.noMatchingFunctionForFunctionCall(functionCall, contextCallerCapabilities: functionDeclarationContext.contractContext.callerCapabilities))
    }

    for argument in functionCall.arguments {
      let result = visit(argument, functionDeclarationContext: functionDeclarationContext)
      mutatingExpressions.append(contentsOf: result.mutatingExpressions)
    }

    return BodyVisitResult(mutatingExpressions: mutatingExpressions)
  }

  func visit(_ subscriptExpression: SubscriptExpression, asLValue: Bool, functionDeclarationContext: FunctionDeclarationContext) -> BodyVisitResult {
    let identifierResult = visit(subscriptExpression.baseIdentifier, asLValue: asLValue, functionDeclarationContext: functionDeclarationContext)
    let indexExpressionResult = visit(subscriptExpression.indexExpression, asLValue: asLValue, functionDeclarationContext: functionDeclarationContext)
    return BodyVisitResult(mutatingExpressions: identifierResult.mutatingExpressions + indexExpressionResult.mutatingExpressions)
  }

  func visit(_ returnStatement: ReturnStatement, functionDeclarationContext: FunctionDeclarationContext) -> BodyVisitResult {
    if let expression = returnStatement.expression {
      return visit(expression, functionDeclarationContext: functionDeclarationContext)
    }
    return BodyVisitResult(mutatingExpressions: [])
  }

  func visit(_ ifStatement: IfStatement, depth: Int, functionDeclarationContext: FunctionDeclarationContext) -> BodyVisitResult {
    return visitBody(ifStatement.body, depth: depth + 1, functionDeclarationContext: functionDeclarationContext)
  }
}
