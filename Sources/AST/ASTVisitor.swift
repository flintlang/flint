//
//  ASTVisitor.swift
//  AST
//
//  Created by Franklin Schrans on 1/16/18.
//

/// Visits an AST using an `ASTPass`.
///
/// The class defines `visit` functions for each AST node, which take as an additional argument an `ASTPassContext`,
/// which records information collected during visits of previous nodes. A visit returns an `ASTPassResult`, which
/// consists of a new `ASTPassContext` and the AST node which replaces the node currently being visited.
///
/// In each of the `visit` functions, the given `ASTPass`'s `process` function is called on the node, then the node's
/// children are visited, then `postProcess` is called on the node.
public struct ASTVisitor<Pass: ASTPass> {
  var pass: Pass

  public init(pass: Pass) {
    self.pass = pass
  }

  public func visit(_ topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule> {
    // Process the TopLevelModule node.
    var processResult = pass.process(topLevelModule: topLevelModule, passContext: passContext)

    // Visit each child node (in this case, each declaration), by updating `processResult`'s `passContext`, and
    // replacing each child node (declaration) by the node returned by `visit`.
    processResult.element.declarations = processResult.element.declarations.map { declaration in
      processResult.combining(visit(declaration, passContext: processResult.passContext))
    }

    // Call `postProcess` on the node.
    let postProcessResult = pass.postProcess(topLevelModule: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ topLevelDeclaration: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration> {
    var processResult = pass.process(topLevelDeclaration: topLevelDeclaration, passContext: passContext)

    switch processResult.element {
    case .contractBehaviorDeclaration(let contractBehaviorDeclaration):

      processResult.element = .contractBehaviorDeclaration(processResult.combining(visit(contractBehaviorDeclaration, passContext: processResult.passContext)))
    case .contractDeclaration(let contractDeclaration):
      processResult.element = .contractDeclaration(processResult.combining(visit(contractDeclaration, passContext: processResult.passContext)))
    case .structDeclaration(let structDeclaration):
      processResult.element = .structDeclaration(processResult.combining(visit(structDeclaration, passContext: processResult.passContext)))
    case .enumDeclaration(let enumDeclaration):
      processResult.element = .enumDeclaration(processResult.combining(visit(enumDeclaration, passContext: processResult.passContext)))
    }

    let postProcessResult = pass.postProcess(topLevelDeclaration: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    var processResult = pass.process(contractDeclaration: contractDeclaration, passContext: passContext)

    processResult.element.identifier = processResult.combining(visit(processResult.element.identifier, passContext: processResult.passContext))

    processResult.element.states = processResult.element.states.map { typeState in
      return processResult.combining(visit(typeState, passContext: processResult.passContext))
    }

    processResult.passContext.contractStateDeclarationContext = ContractStateDeclarationContext(contractIdentifier: contractDeclaration.identifier)

    processResult.element.variableDeclarations = processResult.element.variableDeclarations.map { variableDeclaration in
      return processResult.combining(visit(variableDeclaration, passContext: processResult.passContext))
    }

    processResult.passContext.contractStateDeclarationContext = nil

    let postProcessResult = pass.postProcess(contractDeclaration: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    let declarationContext = ContractBehaviorDeclarationContext(contractIdentifier: contractBehaviorDeclaration.contractIdentifier, typeStates: contractBehaviorDeclaration.states, callerCapabilities: contractBehaviorDeclaration.callerCapabilities)

    var localVariables = [VariableDeclaration]()
    if let capabilityBinding = contractBehaviorDeclaration.capabilityBinding {
      localVariables.append(VariableDeclaration(declarationToken: nil, identifier: capabilityBinding, type: Type(inferredType: .basicType(.address), identifier: capabilityBinding)))
    }

    let scopeContext = ScopeContext(localVariables: localVariables)
    let passContext = passContext.withUpdates {
      $0.contractBehaviorDeclarationContext = declarationContext
      $0.scopeContext = scopeContext
    }

    var processResult = pass.process(contractBehaviorDeclaration: contractBehaviorDeclaration, passContext: passContext)

    processResult.element.contractIdentifier = processResult.combining(visit(processResult.element.contractIdentifier, passContext: processResult.passContext))

    processResult.element.states = processResult.element.states.map { typeState in
      return processResult.combining(visit(typeState, passContext: processResult.passContext))
    }

    if let capabilityBinding = processResult.element.capabilityBinding {
      processResult.element.capabilityBinding = processResult.combining(visit(capabilityBinding, passContext: processResult.passContext))
    }

    processResult.element.callerCapabilities = processResult.element.callerCapabilities.map { callerCapability in
      return processResult.combining(visit(callerCapability, passContext: processResult.passContext))
    }

    let typeScopeContext = processResult.passContext.scopeContext

    processResult.element.members = processResult.element.members.map { member in
      processResult.passContext.scopeContext = typeScopeContext
      return processResult.combining(visit(member, passContext: processResult.passContext))
    }

    processResult.passContext.contractBehaviorDeclarationContext = nil
    processResult.passContext.scopeContext = nil

    let postProcessResult = pass.postProcess(contractBehaviorDeclaration: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ structDeclaration: StructDeclaration, passContext: ASTPassContext) -> ASTPassResult<StructDeclaration> {
    var processResult = pass.process(structDeclaration: structDeclaration, passContext: passContext)

    let declarationContext = StructDeclarationContext(structIdentifier: structDeclaration.identifier)
    let scopeContext = ScopeContext()

    processResult.passContext = processResult.passContext.withUpdates {
      $0.structDeclarationContext = declarationContext
      $0.scopeContext = scopeContext
    }

    processResult.element.identifier = processResult.combining(visit(processResult.element.identifier, passContext: processResult.passContext))

    processResult.element.members = processResult.element.members.map { structMember in
      processResult.passContext.scopeContext = ScopeContext()
      return processResult.combining(visit(structMember, passContext: processResult.passContext))
    }

    processResult.passContext.structDeclarationContext = nil
    processResult.passContext.scopeContext = nil

    let postProcessResult = pass.postProcess(structDeclaration: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ structMember: StructMember, passContext: ASTPassContext) -> ASTPassResult<StructMember> {
    var processResult = pass.process(structMember: structMember, passContext: passContext)

    switch processResult.element {
    case .functionDeclaration(let functionDeclaration):
      processResult.element = .functionDeclaration(processResult.combining(visit(functionDeclaration, passContext: processResult.passContext)))
    case .variableDeclaration(let variableDeclaration):
      processResult.element = .variableDeclaration(processResult.combining(visit(variableDeclaration, passContext: processResult.passContext)))
    case .initializerDeclaration(let initializerDeclaration):
      processResult.element = .initializerDeclaration(processResult.combining(visit(initializerDeclaration, passContext: processResult.passContext)))
    }

    let postProcessResult = pass.postProcess(structMember: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ enumDeclaration: EnumDeclaration, passContext: ASTPassContext) -> ASTPassResult<EnumDeclaration> {
    var processResult = pass.process(enumDeclaration: enumDeclaration, passContext: passContext)

    let declarationContext = EnumDeclarationContext(enumIdentifier: enumDeclaration.identifier)

    processResult.passContext = processResult.passContext.withUpdates {
      $0.enumDeclarationContext = declarationContext
    }

    processResult.element.identifier = processResult.combining(visit(processResult.element.identifier, passContext: processResult.passContext))

    processResult.element.cases = processResult.element.cases.map { enumCase in
      processResult.passContext.scopeContext = ScopeContext()
      return processResult.combining(visit(enumCase, passContext: processResult.passContext))
    }


    processResult.passContext.enumDeclarationContext = nil

    let postProcessResult = pass.postProcess(enumDeclaration: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ enumCase: EnumCase, passContext: ASTPassContext) -> ASTPassResult<EnumCase> {
    var processResult = pass.process(enumCase: enumCase, passContext: passContext)

    processResult.element.identifier = processResult.combining(visit(processResult.element.identifier, passContext: processResult.passContext))

    let postProcessResult = pass.postProcess(enumCase: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ contractBehaviorMember: ContractBehaviorMember, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorMember> {
    var processResult = pass.process(contractBehaviorMember: contractBehaviorMember, passContext: passContext)

    switch processResult.element {
    case .functionDeclaration(let functionDeclaration):
      processResult.element = .functionDeclaration(processResult.combining(visit(functionDeclaration, passContext: processResult.passContext)))
    case .initializerDeclaration(let initializerDeclaration):
      processResult.element = .initializerDeclaration(processResult.combining(visit(initializerDeclaration, passContext: processResult.passContext)))
    }

    let postProcessResult = pass.postProcess(contractBehaviorMember: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    var processResult = pass.process(variableDeclaration: variableDeclaration, passContext: passContext)

    processResult.element.identifier = processResult.combining(visit(processResult.element.identifier, passContext: processResult.passContext))
    processResult.element.type = processResult.combining(visit(processResult.element.type, passContext: processResult.passContext))

    if let assignedExpression = processResult.element.assignedExpression {
      let previousScopeContext = processResult.passContext.scopeContext
      // Create an empty scope context.
      processResult.passContext.scopeContext = ScopeContext()
      processResult.passContext.isPropertyDefaultAssignment = true
      processResult.element.assignedExpression = processResult.combining(visit(assignedExpression, passContext: processResult.passContext))
      processResult.passContext.isPropertyDefaultAssignment = false
      processResult.passContext.scopeContext = previousScopeContext
    }

    let postProcessResult = pass.postProcess(variableDeclaration: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    var processResult = pass.process(functionDeclaration: functionDeclaration, passContext: passContext)

    processResult.element.attributes = processResult.element.attributes.map { attribute in
      return processResult.combining(visit(attribute, passContext: processResult.passContext))
    }

    processResult.element.identifier = processResult.combining(visit(processResult.element.identifier, passContext: processResult.passContext))

    processResult.element.parameters = processResult.element.parameters.map { parameter in
      return processResult.combining(visit(parameter, passContext: processResult.passContext))
    }

    if let resultType = processResult.element.resultType {
      processResult.element.resultType = processResult.combining(visit(resultType, passContext: processResult.passContext))
    }

    let functionDeclarationContext = FunctionDeclarationContext(declaration: functionDeclaration)

    processResult.passContext.functionDeclarationContext = functionDeclarationContext

    processResult.passContext.scopeContext!.parameters.append(contentsOf: functionDeclaration.parameters)

    processResult.element.body = processResult.element.body.map { statement in
      return processResult.combining(visit(statement, passContext: processResult.passContext))
    }

    processResult.passContext.functionDeclarationContext = nil

    let postProcessResult = pass.postProcess(functionDeclaration: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ initializerDeclaration: InitializerDeclaration, passContext: ASTPassContext) -> ASTPassResult<InitializerDeclaration> {
    var processResult = pass.process(initializerDeclaration: initializerDeclaration, passContext: passContext)

    processResult.element.attributes = processResult.element.attributes.map { attribute in
      return processResult.combining(visit(attribute, passContext: processResult.passContext))
    }

    processResult.element.parameters = processResult.element.parameters.map { parameter in
      return processResult.combining(visit(parameter, passContext: processResult.passContext))
    }

    let initializerDeclarationContext = InitializerDeclarationContext(declaration: initializerDeclaration)
    processResult.passContext.initializerDeclarationContext = initializerDeclarationContext

    let functionDeclaration = initializerDeclaration.asFunctionDeclaration
    processResult.passContext.scopeContext!.parameters.append(contentsOf: functionDeclaration.parameters)

    processResult.element.body = processResult.element.body.map { statement in
      return processResult.combining(visit(statement, passContext: processResult.passContext))
    }

    processResult.passContext.initializerDeclarationContext = nil

    let postProcessResult = pass.postProcess(initializerDeclaration: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ attribute: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute> {
    let processResult = pass.process(attribute: attribute, passContext: passContext)

    let postProcessResult = pass.postProcess(attribute: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ parameter: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter> {
    var processResult = pass.process(parameter: parameter, passContext: passContext)
    processResult.element.type = processResult.combining(visit(processResult.element.type, passContext: processResult.passContext))

    let postProcessResult = pass.postProcess(parameter: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ typeAnnotation: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation> {
    var processResult = pass.process(typeAnnotation: typeAnnotation, passContext: passContext)
    processResult.element.type = processResult.combining(visit(processResult.element.type, passContext: processResult.passContext))

    let postProcessResult = pass.postProcess(typeAnnotation: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier> {
    let processResult = pass.process(identifier: identifier, passContext: passContext)
    let postProcessResult = pass.postProcess(identifier: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ type: Type, passContext: ASTPassContext) -> ASTPassResult<Type> {
    var processResult = pass.process(type: type, passContext: passContext)

    processResult.element.genericArguments = processResult.element.genericArguments.map { genericArgument in
      return processResult.combining(visit(genericArgument, passContext: processResult.passContext))
    }

    let postProcessResult = pass.postProcess(type: processResult.element, passContext: passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ callerCapability: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability> {
    var processResult = pass.process(callerCapability: callerCapability, passContext: passContext)

    processResult.element.identifier = processResult.combining(visit(processResult.element.identifier, passContext: processResult.passContext))

    let postProcessResult = pass.postProcess(callerCapability: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ typeState: TypeState, passContext: ASTPassContext) -> ASTPassResult<TypeState> {
    var processResult = pass.process(typeState: typeState, passContext: passContext)

    processResult.element.identifier = processResult.combining(visit(processResult.element.identifier, passContext: processResult.passContext))

    let postProcessResult = pass.postProcess(typeState: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression> {
    var processResult = pass.process(expression: expression, passContext: passContext)

    switch processResult.element {
    case .inoutExpression(let inoutExpression):
      processResult.element = .inoutExpression(processResult.combining(visit(inoutExpression, passContext: processResult.passContext)))
    case .binaryExpression(let binaryExpression):
      processResult.element = .binaryExpression(processResult.combining(visit(binaryExpression, passContext: processResult.passContext)))
    case .bracketedExpression(let expression):
      processResult.element = .bracketedExpression(processResult.combining(visit(expression, passContext: processResult.passContext)))
    case .functionCall(let functionCall):
      processResult.element = .functionCall(processResult.combining(visit(functionCall, passContext: processResult.passContext)))
    case .arrayLiteral(let arrayLiteral):
      processResult.element = .arrayLiteral(processResult.combining(visit(arrayLiteral, passContext: processResult.passContext)))
    case .range(let rangeExpression):
      processResult.element = .range(processResult.combining(visit(rangeExpression, passContext: processResult.passContext)))
    case .dictionaryLiteral(let dictionaryLiteral):
      processResult.element = .dictionaryLiteral(processResult.combining(visit(dictionaryLiteral, passContext: processResult.passContext)))
    case .identifier(let identifier):
      processResult.element = .identifier(processResult.combining(visit(identifier, passContext: processResult.passContext)))
    case .literal(let literalToken):
      processResult.element = .literal(processResult.combining(visit(literalToken, passContext: processResult.passContext)))
    case .self(_): break
    case .variableDeclaration(let variableDeclaration):
      processResult.element = .variableDeclaration(processResult.combining(visit(variableDeclaration, passContext: processResult.passContext)))
    case .subscriptExpression(let subscriptExpression):
      processResult.element = .subscriptExpression(processResult.combining(visit(subscriptExpression, passContext: processResult.passContext)))
    case .sequence(let elements):
      processResult.element = .sequence(elements.map { element in
        return processResult.combining(visit(element, passContext: processResult.passContext))
      })
    case .rawAssembly(_): break
    }

    let postProcessResult = pass.postProcess(expression: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    var processResult = pass.process(statement: statement, passContext: passContext)

    switch processResult.element {
    case .expression(let expression):
      processResult.element = .expression(processResult.combining(visit(expression, passContext: processResult.passContext)))
    case .returnStatement(let returnStatement):
      processResult.element = .returnStatement(processResult.combining(visit(returnStatement, passContext: processResult.passContext)))
    case .becomeStatement(let becomeStatement):
      processResult.element = .becomeStatement(processResult.combining(visit(becomeStatement, passContext: processResult.passContext)))
    case .ifStatement(let ifStatement):
      processResult.element = .ifStatement(processResult.combining(visit(ifStatement, passContext: processResult.passContext)))
    case .forStatement(let forStatement):
      processResult.element = .forStatement(processResult.combining(visit(forStatement, passContext: processResult.passContext)))
    }

    let postProcessResult = pass.postProcess(statement: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ inoutExpression: InoutExpression, passContext: ASTPassContext) -> ASTPassResult<InoutExpression> {
    var processResult = pass.process(inoutExpression: inoutExpression, passContext: passContext)
    processResult.element.expression = processResult.combining(visit(processResult.element.expression, passContext: processResult.passContext))

    let postProcessResult = pass.postProcess(inoutExpression: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    var processResult = pass.process(binaryExpression: binaryExpression, passContext: passContext)

    if case .punctuation(let punctuation) = binaryExpression.op.kind, punctuation.isAssignment {
      if case .variableDeclaration(_) = binaryExpression.lhs {} else {
        processResult.passContext.asLValue = true
      }
    }
    if case .punctuation(.dot) = binaryExpression.op.kind {
      processResult.passContext.isEnclosing = true
    }
    processResult.element.lhs = processResult.combining(visit(processResult.element.lhs, passContext: processResult.passContext))

    if !binaryExpression.isExplicitPropertyAccess {
      processResult.passContext.asLValue = false
    }
    processResult.passContext.isEnclosing = false

    switch passContext.environment!.type(of: processResult.element.lhs, enclosingType: passContext.enclosingTypeIdentifier!.name, scopeContext: passContext.scopeContext!) {
    case .arrayType(_):
      break
    case .fixedSizeArrayType(_):
      break
    default:
      processResult.element.rhs = processResult.combining(visit(processResult.element.rhs, passContext: processResult.passContext))
    }

    let postProcessResult = pass.postProcess(binaryExpression: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    var processResult = pass.process(functionCall: functionCall, passContext: passContext)

    processResult.passContext.isFunctionCall = true
    processResult.element.identifier = processResult.combining(visit(processResult.element.identifier, passContext: processResult.passContext))
    processResult.passContext.isFunctionCall = false

    processResult.element.arguments = processResult.element.arguments.map { argument in

      let x = visit(argument, passContext: processResult.passContext)
      return processResult.combining(x)
    }

    let postProcessResult = pass.postProcess(functionCall: processResult.element, passContext: processResult.passContext)

    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ arrayLiteral: ArrayLiteral, passContext: ASTPassContext) -> ASTPassResult<ArrayLiteral> {
    var processResult = pass.process(arrayLiteral: arrayLiteral, passContext: passContext)

    processResult.element.elements = processResult.element.elements.map { element in
      return processResult.combining(visit(element, passContext: processResult.passContext))
    }

    let postProcessResult = pass.postProcess(arrayLiteral: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ rangeExpression: RangeExpression, passContext: ASTPassContext) -> ASTPassResult<RangeExpression> {
    var processResult = pass.process(rangeExpression: rangeExpression, passContext: passContext)
    var element = processResult.element
    element.initial = processResult.combining(visit(element.initial, passContext: processResult.passContext))
    element.bound = processResult.combining(visit(element.bound, passContext: processResult.passContext))

    let postProcessResult = pass.postProcess(rangeExpression: element, passContext: processResult.passContext)
    return ASTPassResult(element: element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ dictionaryLiteral: DictionaryLiteral, passContext: ASTPassContext) -> ASTPassResult<DictionaryLiteral> {
    var processResult = pass.process(dictionaryLiteral: dictionaryLiteral, passContext: passContext)

    processResult.element.elements = processResult.element.elements.map { element in
      var element = element
      element.key = processResult.combining(visit(element.key, passContext: processResult.passContext))
      element.value = processResult.combining(visit(element.value, passContext: processResult.passContext))
      return element
    }

    let postProcessResult = pass.postProcess(dictionaryLiteral: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ literalToken: Token, passContext: ASTPassContext) -> ASTPassResult<Token> {
    let processResult = pass.process(literalToken: literalToken, passContext: passContext)
    let postProcessResult = pass.process(literalToken: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: postProcessResult.diagnostics, passContext: passContext)
  }

  func visit(_ subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    var processResult = pass.process(subscriptExpression: subscriptExpression, passContext: passContext)

    processResult.element.baseExpression = processResult.combining(visit(processResult.element.baseExpression, passContext: processResult.passContext))

    processResult.element.indexExpression = processResult.combining(visit(processResult.element.indexExpression, passContext: processResult.passContext))

    let postProcessResult = pass.postProcess(subscriptExpression: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    var processResult = pass.process(returnStatement: returnStatement, passContext: passContext)

    if let expression = processResult.element.expression {
      processResult.element.expression = processResult.combining(visit(expression, passContext: processResult.passContext))
    }

    let postProcessResult = pass.postProcess(returnStatement: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ becomeStatement: BecomeStatement, passContext: ASTPassContext) -> ASTPassResult<BecomeStatement> {
    var processResult = pass.process(becomeStatement: becomeStatement, passContext: passContext)

    processResult.passContext.isInBecome = true
    processResult.element.expression = processResult.combining(visit(processResult.element.expression, passContext: processResult.passContext))
    processResult.passContext.isInBecome = false

    let postProcessResult = pass.postProcess(becomeStatement: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    var passContext = passContext
    var processResult = pass.process(ifStatement: ifStatement, passContext: passContext)

    processResult.element.condition = processResult.combining(visit(processResult.element.condition, passContext: processResult.passContext))

    let scopeContext = passContext.scopeContext
    processResult.element.body = processResult.element.body.map { statement in
      return processResult.combining(visit(statement, passContext: processResult.passContext))
    }

    if processResult.element.ifBodyScopeContext == nil {
      processResult.element.ifBodyScopeContext = processResult.passContext.scopeContext
    }

    processResult.passContext.scopeContext = scopeContext

    processResult.element.elseBody = processResult.element.elseBody.map { statement in
      return processResult.combining(visit(statement, passContext: processResult.passContext))
    }

    if processResult.element.elseBodyScopeContext == nil {
      processResult.element.elseBodyScopeContext = processResult.passContext.scopeContext
    }

    processResult.passContext.scopeContext = scopeContext

    let postProcessResult = pass.postProcess(ifStatement: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }

  func visit(_ forStatement: ForStatement, passContext: ASTPassContext) -> ASTPassResult<ForStatement> {
    var passContext = passContext
    var processResult = pass.process(forStatement: forStatement, passContext: passContext)

    processResult.element.variable = processResult.combining(visit(processResult.element.variable, passContext: processResult.passContext))
    processResult.element.iterable = processResult.combining(visit(processResult.element.iterable, passContext: processResult.passContext))

    let scopeContext = passContext.scopeContext
    processResult.element.body = processResult.element.body.map { statement in
      return processResult.combining(visit(statement, passContext: processResult.passContext))
    }

    if processResult.element.forBodyScopeContext == nil {
      processResult.element.forBodyScopeContext = processResult.passContext.scopeContext
    }

    processResult.passContext.scopeContext = scopeContext

    let postProcessResult = pass.postProcess(forStatement: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element, diagnostics: processResult.diagnostics + postProcessResult.diagnostics, passContext: postProcessResult.passContext)
  }
}
