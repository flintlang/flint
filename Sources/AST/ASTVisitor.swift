//
//  ASTVisitor.swift
//  AST
//
//  Created by Franklin Schrans on 1/16/18.
//

public struct ASTVisitor<Pass: ASTPass> {
  var pass: Pass

  public init(pass: Pass) {
    self.pass = pass
  }

  public func visit(_ topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule> {
    var preProcessResult = pass.preProcess(topLevelModule: topLevelModule, passContext: passContext)

    preProcessResult.element.declarations = preProcessResult.element.declarations.map { declaration in
      preProcessResult.combining(visit(declaration, passContext: preProcessResult.passContext))
    }

    let postProcessResult = pass.postProcess(topLevelModule: preProcessResult.element, passContext: preProcessResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: preProcessResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ topLevelDeclaration: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration> {
    var preProcessResult = pass.preProcess(topLevelDeclaration: topLevelDeclaration, passContext: passContext)
    
    switch preProcessResult.element {
    case .contractBehaviorDeclaration(let contractBehaviorDeclaration):
      preProcessResult.element = .contractBehaviorDeclaration(preProcessResult.combining(visit(contractBehaviorDeclaration, passContext: preProcessResult.passContext)))
    case .contractDeclaration(let contractDeclaration):
      preProcessResult.element = .contractDeclaration(preProcessResult.combining(visit(contractDeclaration, passContext: preProcessResult.passContext)))
    }

    let postProcessResult = pass.postProcess(topLevelDeclaration: preProcessResult.element, passContext: preProcessResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: preProcessResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    var preProcessResult = pass.preProcess(contractDeclaration: contractDeclaration, passContext: passContext)

    preProcessResult.element.identifier = preProcessResult.combining(visit(preProcessResult.element.identifier, passContext: preProcessResult.passContext))

    preProcessResult.element.variableDeclarations = preProcessResult.element.variableDeclarations.map { variableDeclaration in
      return preProcessResult.combining(visit(variableDeclaration, passContext: preProcessResult.passContext))
    }

    let postProcessResult = pass.postProcess(contractDeclaration: preProcessResult.element, passContext: preProcessResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: preProcessResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    var preProcessResult = pass.preProcess(contractBehaviorDeclaration: contractBehaviorDeclaration, passContext: passContext)

    preProcessResult.element.contractIdentifier = preProcessResult.combining(visit(preProcessResult.element.contractIdentifier, passContext: preProcessResult.passContext))

    if let capabilityBinding = preProcessResult.element.capabilityBinding {
      preProcessResult.element.capabilityBinding = preProcessResult.combining(visit(capabilityBinding, passContext: preProcessResult.passContext))
    }

    preProcessResult.element.callerCapabilities = preProcessResult.element.callerCapabilities.map { callerCapability in
      return preProcessResult.combining(visit(callerCapability, passContext: preProcessResult.passContext))
    }

    preProcessResult.element.functionDeclarations = preProcessResult.element.functionDeclarations.map { functionDeclaration in
      return preProcessResult.combining(visit(functionDeclaration, passContext: preProcessResult.passContext))
    }

    let postProcessResult = pass.postProcess(contractBehaviorDeclaration: preProcessResult.element, passContext: preProcessResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: preProcessResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    var preProcessResult = pass.preProcess(variableDeclaration: variableDeclaration, passContext: passContext)

    preProcessResult.element.identifier = preProcessResult.combining(visit(preProcessResult.element.identifier, passContext: preProcessResult.passContext))
    preProcessResult.element.type = preProcessResult.combining(visit(preProcessResult.element.type, passContext: preProcessResult.passContext))

    let postProcessResult = pass.postProcess(variableDeclaration: preProcessResult.element, passContext: preProcessResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: preProcessResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    var preProcessResult = pass.preProcess(functionDeclaration: functionDeclaration, passContext: passContext)

    preProcessResult.element.attributes = preProcessResult.element.attributes.map { attribute in
      return preProcessResult.combining(visit(attribute, passContext: preProcessResult.passContext))
    }

    preProcessResult.element.identifier = preProcessResult.combining(visit(preProcessResult.element.identifier, passContext: preProcessResult.passContext))

    preProcessResult.element.parameters = preProcessResult.element.parameters.map { parameter in
      return preProcessResult.combining(visit(parameter, passContext: preProcessResult.passContext))
    }

    if let resultType = preProcessResult.element.resultType {
      preProcessResult.element.resultType = preProcessResult.combining(visit(resultType, passContext: preProcessResult.passContext))
    }

    preProcessResult.element.body = preProcessResult.element.body.map { statement in
      return preProcessResult.combining(visit(statement, passContext: preProcessResult.passContext))
    }

    let postProcessResult = pass.postProcess(functionDeclaration: preProcessResult.element, passContext: preProcessResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: preProcessResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ attribute: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute> {
    let preProcessResult = pass.preProcess(attribute: attribute, passContext: passContext)

    let postProcessResult = pass.postProcess(attribute: preProcessResult.element, passContext: preProcessResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: preProcessResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ parameter: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter> {
    var preProcessResult = pass.preProcess(parameter: parameter, passContext: passContext)
    preProcessResult.element.type = preProcessResult.combining(visit(preProcessResult.element.type, passContext: preProcessResult.passContext))

    let postProcessResult = pass.postProcess(parameter: preProcessResult.element, passContext: preProcessResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: preProcessResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ typeAnnotation: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation> {
    var preProcessResult = pass.preProcess(typeAnnotation: typeAnnotation, passContext: passContext)
    preProcessResult.element.type = preProcessResult.combining(visit(preProcessResult.element.type, passContext: preProcessResult.passContext))

    let postProcessResult = pass.postProcess(typeAnnotation: preProcessResult.element, passContext: preProcessResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: preProcessResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier> {
    let preProcessResult = pass.preProcess(identifier: identifier, passContext: passContext)
    let postProcessResult = pass.postProcess(identifier: preProcessResult.element, passContext: preProcessResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: preProcessResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ type: Type, passContext: ASTPassContext) -> ASTPassResult<Type> {
    var preProcessResult = pass.preProcess(type: type, passContext: passContext)

    preProcessResult.element.genericArguments = preProcessResult.element.genericArguments.map { genericArgument in
      return preProcessResult.combining(visit(genericArgument, passContext: preProcessResult.passContext))
    }

    let postProcessResult = pass.postProcess(type: preProcessResult.element, passContext: passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: preProcessResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ callerCapability: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability> {
    var preProcessResult = pass.preProcess(callerCapability: callerCapability, passContext: passContext)

    preProcessResult.element.identifier = preProcessResult.combining(visit(preProcessResult.element.identifier, passContext: preProcessResult.passContext))

    let postProcessResult = pass.postProcess(callerCapability: preProcessResult.element, passContext: preProcessResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: preProcessResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression> {
    var preProcessResult = pass.preProcess(expression: expression, passContext: passContext)

    switch preProcessResult.element {
    case .binaryExpression(let binaryExpression):
      preProcessResult.element = .binaryExpression(preProcessResult.combining(visit(binaryExpression, passContext: preProcessResult.passContext)))
    case .bracketedExpression(let expression):
      preProcessResult.element = .bracketedExpression(preProcessResult.combining(visit(expression, passContext: preProcessResult.passContext)))
    case .functionCall(let functionCall):
      preProcessResult.element = .functionCall(preProcessResult.combining(visit(functionCall, passContext: preProcessResult.passContext)))
    case .identifier(let identifier):
      preProcessResult.element = .identifier(preProcessResult.combining(visit(identifier, passContext: preProcessResult.passContext)))
    case .literal(_), .self(_): break
    case .variableDeclaration(let variableDeclaration):
      preProcessResult.element = .variableDeclaration(preProcessResult.combining(visit(variableDeclaration, passContext: preProcessResult.passContext)))
    case .subscriptExpression(let subscriptExpression):
      preProcessResult.element = .subscriptExpression(preProcessResult.combining(visit(subscriptExpression, passContext: preProcessResult.passContext)))
    }

    let postProcessResult = pass.postProcess(expression: preProcessResult.element, passContext: preProcessResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: preProcessResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    var preProcessResult = pass.preProcess(statement: statement, passContext: passContext)

    switch preProcessResult.element {
    case .expression(let expression):
      preProcessResult.element = .expression(preProcessResult.combining(visit(expression, passContext: preProcessResult.passContext)))
    case .returnStatement(let returnStatement):
      preProcessResult.element = .returnStatement(preProcessResult.combining(visit(returnStatement, passContext: preProcessResult.passContext)))
    case .ifStatement(let ifStatement):
      preProcessResult.element = .ifStatement(preProcessResult.combining(visit(ifStatement, passContext: preProcessResult.passContext)))
    }

    let postProcessResult = pass.postProcess(statement: preProcessResult.element, passContext: preProcessResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: preProcessResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    var preProcessResult = pass.preProcess(binaryExpression: binaryExpression, passContext: passContext)

    if case .punctuation(let punctuation) = binaryExpression.op.kind, punctuation.isAssignment  {
      preProcessResult.passContext.asLValue = true
    }
    preProcessResult.element.lhs = preProcessResult.combining(visit(preProcessResult.element.lhs, passContext: preProcessResult.passContext))
    preProcessResult.passContext.asLValue = false

    preProcessResult.element.rhs = preProcessResult.combining(visit(preProcessResult.element.rhs, passContext: preProcessResult.passContext))

    let postProcessResult = pass.postProcess(binaryExpression: preProcessResult.element, passContext: preProcessResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: preProcessResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    var preProcessResult = pass.preProcess(functionCall: functionCall, passContext: passContext)

    preProcessResult.element.identifier = preProcessResult.combining(visit(preProcessResult.element.identifier, passContext: preProcessResult.passContext))

    preProcessResult.element.arguments = preProcessResult.element.arguments.map { argument in
      return preProcessResult.combining(visit(argument, passContext: preProcessResult.passContext))
    }

    let postProcessResult = pass.postProcess(functionCall: preProcessResult.element, passContext: preProcessResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: preProcessResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    var preProcessResult = pass.preProcess(subscriptExpression: subscriptExpression, passContext: passContext)

    preProcessResult.element.baseIdentifier = preProcessResult.combining(visit(preProcessResult.element.baseIdentifier, passContext: preProcessResult.passContext))

    preProcessResult.element.indexExpression = preProcessResult.combining(visit(preProcessResult.element.indexExpression, passContext: preProcessResult.passContext))

    let postProcessResult = pass.postProcess(subscriptExpression: preProcessResult.element, passContext: preProcessResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: preProcessResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    var preProcessResult = pass.preProcess(returnStatement: returnStatement, passContext: passContext)

    if let expression = preProcessResult.element.expression {
      preProcessResult.element.expression = preProcessResult.combining(visit(expression, passContext: preProcessResult.passContext))
    }

    let postProcessResult = pass.postProcess(returnStatement: preProcessResult.element, passContext: preProcessResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: preProcessResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    var preProcessResult = pass.preProcess(ifStatement: ifStatement, passContext: passContext)

    preProcessResult.element.condition = preProcessResult.combining(visit(preProcessResult.element.condition, passContext: preProcessResult.passContext))

    preProcessResult.element.body = preProcessResult.element.body.map { statement in
      return preProcessResult.combining(visit(statement, passContext: preProcessResult.passContext))
    }

    preProcessResult.element.elseBody = preProcessResult.element.body.map { statement in
      return preProcessResult.combining(visit(statement, passContext: preProcessResult.passContext))
    }

    let postProcessResult = pass.postProcess(ifStatement: preProcessResult.element, passContext: preProcessResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: preProcessResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }
}
