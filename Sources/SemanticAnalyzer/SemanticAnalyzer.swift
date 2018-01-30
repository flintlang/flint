//
//  SemanticAnalyzer.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 12/26/17.
//

import AST

public struct SemanticAnalyzer: ASTPass {
  public init() {}

  public func process(topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule> {
    return ASTPassResult(element: topLevelModule, diagnostics: [], passContext: passContext)
  }

  public func process(topLevelDeclaration: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration> {
    return ASTPassResult(element: topLevelDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    return ASTPassResult(element: contractDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    var diagnostics = [Diagnostic]()

    let environment = passContext.environment!

    if !environment.declaredContractsIdentifiers.contains(contractBehaviorDeclaration.contractIdentifier) {
      diagnostics.append(.contractBehaviorDeclarationNoMatchingContract(contractBehaviorDeclaration))
    }

    let properties = environment.properties(declaredIn: contractBehaviorDeclaration.contractIdentifier)
    let declarationContext = ContractBehaviorDeclarationContext(contractIdentifier: contractBehaviorDeclaration.contractIdentifier, contractProperties: properties, callerCapabilities: contractBehaviorDeclaration.callerCapabilities)

    let passContext = passContext.withUpdates { $0.contractBehaviorDeclarationContext = declarationContext }

    return ASTPassResult(element: contractBehaviorDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(structDeclaration: StructDeclaration, passContext: ASTPassContext) -> ASTPassResult<StructDeclaration> {
    return ASTPassResult(element: structDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(structMember: StructMember, passContext: ASTPassContext) -> ASTPassResult<StructMember> {
    return ASTPassResult(element: structMember, diagnostics: [], passContext: passContext)
  }

  public func process(variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    var passContext = passContext
    passContext.scopeContext?.localVariables += [variableDeclaration]

    return ASTPassResult(element: variableDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    var diagnostics = [Diagnostic]()

    if functionDeclaration.isPayable {
      let payableValueParameters = functionDeclaration.parameters.filter { $0.isPayableValueParameter }
      if payableValueParameters.count > 1 {
        diagnostics.append(.ambiguousPayableValueParameter(functionDeclaration))
      } else if payableValueParameters.count == 0 {
        diagnostics.append(.payableFunctionDoesNotHavePayableValueParameter(functionDeclaration))
      }
    }

    let statements = functionDeclaration.body
    let returnStatementIndex = statements.index(where: { statement in
      if case .returnStatement(_) = statement { return true }
      return false
    })

    if let returnStatementIndex = returnStatementIndex {
      if returnStatementIndex != statements.count - 1 {
        let nextStatement = statements[returnStatementIndex + 1]
        diagnostics.append(.codeAfterReturn(nextStatement))
      }
    } else {
      if let resultType = functionDeclaration.resultType {
        diagnostics.append(.missingReturnInNonVoidFunction(closeBraceToken: functionDeclaration.closeBraceToken, resultType: resultType))
      }
    }

    return ASTPassResult(element: functionDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(attribute: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute> {
    return ASTPassResult(element: attribute, diagnostics: [], passContext: passContext)
  }

  public func process(parameter: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter> {
    return ASTPassResult(element: parameter, diagnostics: [], passContext: passContext)
  }

  public func process(typeAnnotation: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation> {
    return ASTPassResult(element: typeAnnotation, diagnostics: [], passContext: passContext)
  }

  public func process(identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier> {
    var identifier = identifier
    var passContext = passContext
    var diagnostics = [Diagnostic]()

    if let isFunctionCall = passContext.isFunctionCall, isFunctionCall {
    } else if let functionDeclarationContext = passContext.functionDeclarationContext {
      if !passContext.scopeContext!.containsVariableDefinition(for: identifier.name) {
        if let isFunctionCall = passContext.isFunctionCall, isFunctionCall {
        } else {
          identifier.isPropertyAccess = true
        }
      }

      if identifier.isPropertyAccess {
        let contractBehaviorDeclarationContext = passContext.contractBehaviorDeclarationContext!
        if !contractBehaviorDeclarationContext.isPropertyDeclared(identifier.name) {
          diagnostics.append(.useOfUndeclaredIdentifier(identifier))
          passContext.environment!.addUsedUndefinedVariable(identifier, contractIdentifier: contractBehaviorDeclarationContext.contractIdentifier)
        } else if let asLValue = passContext.asLValue, asLValue {
          if !functionDeclarationContext.isMutating {
            diagnostics.append(.useOfMutatingExpressionInNonMutatingFunction(.identifier(identifier), functionDeclaration: functionDeclarationContext.declaration))
          }
          addMutatingExpression(.identifier(identifier), passContext: &passContext)
        }
      }
    }

    return ASTPassResult(element: identifier, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(type: Type, passContext: ASTPassContext) -> ASTPassResult<Type> {
    return ASTPassResult(element: type, diagnostics: [], passContext: passContext)
  }

  public func process(callerCapability: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability> {
    let contractBehaviorDeclarationContext = passContext.contractBehaviorDeclarationContext!
    let environment = passContext.environment!
    var diagnostics = [Diagnostic]()

    if !callerCapability.isAny && !environment.containsCallerCapability(callerCapability, in: contractBehaviorDeclarationContext.contractIdentifier) {
      diagnostics.append(.undeclaredCallerCapability(callerCapability, contractIdentifier: contractBehaviorDeclarationContext.contractIdentifier))
    }

    return ASTPassResult(element: callerCapability, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression> {
    return ASTPassResult(element: expression, diagnostics: [], passContext: passContext)
  }

  public func process(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    return ASTPassResult(element: statement, diagnostics: [], passContext: passContext)
  }

  public func process(binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    var binaryExpression = binaryExpression

    if case .self(_) = binaryExpression.lhs, case .identifier(var identifier) = binaryExpression.rhs {
        identifier.isPropertyAccess = true
        binaryExpression.rhs = .identifier(identifier)
    }

    return ASTPassResult(element: binaryExpression, diagnostics: [], passContext: passContext)
  }

  public func process(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    var passContext = passContext
    let functionDeclarationContext = passContext.functionDeclarationContext!
    let environment = passContext.environment!
    let contractBehaviorDeclarationContext = passContext.contractBehaviorDeclarationContext!
    var diagnostics = [Diagnostic]()

    switch environment.matchFunctionCall(functionCall, contractIdentifier: contractBehaviorDeclarationContext.contractIdentifier, callerCapabilities: contractBehaviorDeclarationContext.callerCapabilities) {
    case .success(let matchingFunction):
      if matchingFunction.isMutating {
        addMutatingExpression(.functionCall(functionCall), passContext: &passContext)

        if !functionDeclarationContext.isMutating {
          diagnostics.append(.useOfMutatingExpressionInNonMutatingFunction(.functionCall(functionCall), functionDeclaration: functionDeclarationContext.declaration))
        }
      }
    case .failure(candidates: let candidates):
      if environment.matchEventCall(functionCall, contractIdentifier: contractBehaviorDeclarationContext.contractIdentifier) == nil {
        diagnostics.append(.noMatchingFunctionForFunctionCall(functionCall, contextCallerCapabilities: contractBehaviorDeclarationContext.callerCapabilities, candidates: candidates))
      }
    }

    return ASTPassResult(element: functionCall, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    return ASTPassResult(element: subscriptExpression, diagnostics: [], passContext: passContext)
  }

  public func process(returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    return ASTPassResult(element: returnStatement, diagnostics: [], passContext: passContext)
  }

  public func process(ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    return ASTPassResult(element: ifStatement, diagnostics: [], passContext: passContext)
  }

  public func postProcess(topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule> {
    return ASTPassResult(element: topLevelModule, diagnostics: [], passContext: passContext)
  }

  public func postProcess(topLevelDeclaration: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration> {
    return ASTPassResult(element: topLevelDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    return ASTPassResult(element: contractDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    return ASTPassResult(element: contractBehaviorDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(structDeclaration: StructDeclaration, passContext: ASTPassContext) -> ASTPassResult<StructDeclaration> {
    return ASTPassResult(element: structDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(structMember: StructMember, passContext: ASTPassContext) -> ASTPassResult<StructMember> {
    return ASTPassResult(element: structMember, diagnostics: [], passContext: passContext)
  }

  public func postProcess(variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    return ASTPassResult(element: variableDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    var functionDeclaration = functionDeclaration
    let mutatingExpressions = passContext.mutatingExpressions ?? []
    var diagnostics = [Diagnostic]()

    if functionDeclaration.isMutating, mutatingExpressions.isEmpty {
      diagnostics.append(.functionCanBeDeclaredNonMutating(functionDeclaration.mutatingToken))
    }

    functionDeclaration.localVariables = passContext.scopeContext!.localVariables

    let passContext = passContext.withUpdates { $0.mutatingExpressions = nil }
    return ASTPassResult(element: functionDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  public func postProcess(attribute: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute> {
    return ASTPassResult(element: attribute, diagnostics: [], passContext: passContext)
  }

  public func postProcess(parameter: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter> {
    return ASTPassResult(element: parameter, diagnostics: [], passContext: passContext)
  }

  public func postProcess(typeAnnotation: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation> {
    return ASTPassResult(element: typeAnnotation, diagnostics: [], passContext: passContext)
  }

  public func postProcess(identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier> {
    return ASTPassResult(element: identifier, diagnostics: [], passContext: passContext)
  }

  public func postProcess(type: Type, passContext: ASTPassContext) -> ASTPassResult<Type> {
    return ASTPassResult(element: type, diagnostics: [], passContext: passContext)
  }

  public func postProcess(callerCapability: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability> {
    return ASTPassResult(element: callerCapability, diagnostics: [], passContext: passContext)
  }

  public func postProcess(expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression> {
    return ASTPassResult(element: expression, diagnostics: [], passContext: passContext)
  }

  public func postProcess(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    return ASTPassResult(element: statement, diagnostics: [], passContext: passContext)
  }

  public func postProcess(binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    return ASTPassResult(element: binaryExpression, diagnostics: [], passContext: passContext)
  }

  public func postProcess(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
  }

  public func postProcess(subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    return ASTPassResult(element: subscriptExpression, diagnostics: [], passContext: passContext)
  }

  public func postProcess(returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    return ASTPassResult(element: returnStatement, diagnostics: [], passContext: passContext)
  }

  public func postProcess(ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    return ASTPassResult(element: ifStatement, diagnostics: [], passContext: passContext)
  }

  private func addMutatingExpression(_ mutatingExpression: Expression, passContext: inout ASTPassContext) {
    let mutatingExpressions = (passContext.mutatingExpressions ?? []) + [mutatingExpression]
    passContext.mutatingExpressions = mutatingExpressions
  }
}

extension ASTPassContext {
  var mutatingExpressions: [Expression]? {
    get { return self[MutatingExpressionContextEntry.self] }
    set { self[MutatingExpressionContextEntry.self] = newValue }
  }
}

struct MutatingExpressionContextEntry: PassContextEntry {
  typealias Value = [Expression]
}
