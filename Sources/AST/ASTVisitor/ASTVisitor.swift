//
//  ASTVisitor.swift
//  AST
//
//  Created by Franklin Schrans on 1/16/18.
//
import Lexer

/// Visits an AST using an `ASTPass`.
///
/// The class defines `visit` functions for each AST node, which take as an additional argument an `ASTPassContext`,
/// which records information collected during visits of previous nodes. A visit returns an `ASTPassResult`, which
/// consists of a new `ASTPassContext` and the AST node which replaces the node currently being visited.
///
/// In each of the `visit` functions, the given `ASTPass`'s `process` function is called on the node, then the node's
/// children are visited, then `postProcess` is called on the node.
public struct ASTVisitor {
  var pass: ASTPass

  public init(pass: ASTPass) {
    self.pass = pass
  }

  // MARK: Modules
  public func visit(_ topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule> {
    var processResult = pass.process(topLevelModule: topLevelModule, passContext: passContext)

    // Visit each child node (in this case, each declaration), by updating `processResult`'s `passContext`, and
    // replacing each child node (declaration) by the node returned by `visit`.
    processResult.element.declarations = processResult.element.declarations.map { declaration in
      processResult.combining(visit(declaration, passContext: processResult.passContext))
    }

    // Call `postProcess` on the node.
    let postProcessResult = pass.postProcess(topLevelModule: processResult.element,
                                             passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  // MARK: Top Level Declarations
  func visit(_ topLevelDeclaration: TopLevelDeclaration,
             passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration> {
    var processResult = pass.process(topLevelDeclaration: topLevelDeclaration, passContext: passContext)
    switch processResult.element {
    case .contractBehaviorDeclaration(let contractBehaviorDeclaration):
      processResult.element = .contractBehaviorDeclaration(
        processResult.combining(visit(contractBehaviorDeclaration, passContext: processResult.passContext)))
    case .contractDeclaration(let contractDeclaration):
      processResult.element = .contractDeclaration(
        processResult.combining(visit(contractDeclaration, passContext: processResult.passContext)))
    case .structDeclaration(let structDeclaration):
      processResult.element = .structDeclaration(
        processResult.combining(visit(structDeclaration, passContext: processResult.passContext)))
    case .enumDeclaration(let enumDeclaration):
      processResult.element = .enumDeclaration(
        processResult.combining(visit(enumDeclaration, passContext: processResult.passContext)))
    case .traitDeclaration(let traitDeclaration):
      processResult.element = .traitDeclaration(
        processResult.combining(visit(traitDeclaration, passContext: processResult.passContext)))
    }

    let postProcessResult = pass.postProcess(topLevelDeclaration: processResult.element,
                                             passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ contractDeclaration: ContractDeclaration,
             passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    var processResult = pass.process(contractDeclaration: contractDeclaration, passContext: passContext)

    processResult.element.identifier = processResult.combining(visit(processResult.element.identifier,
                                                                     passContext: processResult.passContext))

    processResult.passContext.contractStateDeclarationContext =
      ContractStateDeclarationContext(contractIdentifier: contractDeclaration.identifier)

    processResult.element.conformances = processResult.element.conformances.map { conformance in
      return processResult.combining(visit(conformance, passContext: processResult.passContext))
    }

    processResult.element.states = processResult.element.states.map { typeState in
      return processResult.combining(visit(typeState, passContext: processResult.passContext))
    }

    processResult.element.members = processResult.element.members.map { member in
      return processResult.combining(visit(member, passContext: processResult.passContext))
    }

    processResult.passContext.contractStateDeclarationContext = nil

    let postProcessResult = pass.postProcess(contractDeclaration: processResult.element,
                                             passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ contractBehaviorDeclaration: ContractBehaviorDeclaration,
             passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    let declarationContext =
      ContractBehaviorDeclarationContext(contractIdentifier: contractBehaviorDeclaration.contractIdentifier,
                                         typeStates: contractBehaviorDeclaration.states,
                                         callerProtections: contractBehaviorDeclaration.callerProtections)

    var localVariables = [VariableDeclaration]()
    if let callerBinding = contractBehaviorDeclaration.callerBinding {
      localVariables.append(VariableDeclaration(modifiers: [],
                                                declarationToken: nil,
                                                identifier: callerBinding,
                                                type: Type(inferredType: .basicType(.address),
                                                           identifier: callerBinding)))
    }

    let scopeContext = ScopeContext(localVariables: localVariables)
    let passContext = passContext.withUpdates {
      $0.contractBehaviorDeclarationContext = declarationContext
      $0.scopeContext = scopeContext
    }

    var processResult = pass.process(contractBehaviorDeclaration: contractBehaviorDeclaration, passContext: passContext)

    processResult.element.contractIdentifier =
      processResult.combining(visit(processResult.element.contractIdentifier, passContext: processResult.passContext))

    processResult.element.states = processResult.element.states.map { typeState in
      return processResult.combining(visit(typeState, passContext: processResult.passContext))
    }

    if let callerBinding = processResult.element.callerBinding {
      processResult.element.callerBinding =
        processResult.combining(visit(callerBinding, passContext: processResult.passContext))
    }

    processResult.element.callerProtections = processResult.element.callerProtections.map { callerProtection in
      return processResult.combining(visit(callerProtection, passContext: processResult.passContext))
    }

    let typeScopeContext = processResult.passContext.scopeContext

    processResult.element.members = processResult.element.members.map { member in
      processResult.passContext.scopeContext = typeScopeContext
      return processResult.combining(visit(member, passContext: processResult.passContext))
    }

    processResult.passContext.contractBehaviorDeclarationContext = nil
    processResult.passContext.scopeContext = nil

    let postProcessResult = pass.postProcess(contractBehaviorDeclaration: processResult.element,
                                             passContext: processResult.passContext)

    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ structDeclaration: StructDeclaration, passContext: ASTPassContext) -> ASTPassResult<StructDeclaration> {
    var processResult = pass.process(structDeclaration: structDeclaration, passContext: passContext)

    let declarationContext = StructDeclarationContext(structIdentifier: structDeclaration.identifier)
    let scopeContext = ScopeContext()

    processResult.passContext = processResult.passContext.withUpdates {
      $0.structDeclarationContext = declarationContext
      $0.scopeContext = scopeContext
    }

    processResult.element.identifier =
      processResult.combining(visit(processResult.element.identifier, passContext: processResult.passContext))

    processResult.element.members = processResult.element.members.map { structMember in
      processResult.passContext.scopeContext = ScopeContext()
      return processResult.combining(visit(structMember, passContext: processResult.passContext))
    }

    processResult.passContext.structDeclarationContext = nil
    processResult.passContext.scopeContext = nil

    let postProcessResult =
      pass.postProcess(structDeclaration: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ enumDeclaration: EnumDeclaration, passContext: ASTPassContext) -> ASTPassResult<EnumDeclaration> {
    var processResult = pass.process(enumDeclaration: enumDeclaration, passContext: passContext)

    let declarationContext = EnumDeclarationContext(enumIdentifier: enumDeclaration.identifier)

    processResult.passContext = processResult.passContext.withUpdates {
      $0.enumDeclarationContext = declarationContext
    }

    processResult.element.identifier =
      processResult.combining(visit(processResult.element.identifier,
                                    passContext: processResult.passContext))

    processResult.element.cases = processResult.element.cases.map { enumCase in
      processResult.passContext.scopeContext = ScopeContext()
      return processResult.combining(visit(enumCase, passContext: processResult.passContext))
    }

    processResult.passContext.enumDeclarationContext = nil

    let postProcessResult =
      pass.postProcess(enumDeclaration: processResult.element,
                       passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ traitDeclaration: TraitDeclaration, passContext: ASTPassContext) -> ASTPassResult<TraitDeclaration> {
    var processResult = pass.process(traitDeclaration: traitDeclaration, passContext: passContext)

    processResult.element.identifier =
      processResult.combining(visit(processResult.element.identifier,
                                    passContext: processResult.passContext))

    let traitDeclarationContext = TraitDeclarationContext(traitIdentifier: processResult.element.identifier,
                                                          traitKind: processResult.element.traitKind)
    let traitScopeContext = ScopeContext()

    processResult.passContext = processResult.passContext.withUpdates {
      $0.traitDeclarationContext = traitDeclarationContext
      $0.scopeContext = traitScopeContext
    }

    // visit trait members
    processResult.element.members = processResult.element.members.map { member in
      processResult.passContext.scopeContext = traitScopeContext
      return processResult.combining(visit(member, passContext: processResult.passContext))
    }

    processResult.passContext.traitDeclarationContext = nil
    processResult.passContext.scopeContext = nil

    let postProcessResult = pass.postProcess(traitDeclaration: processResult.element,
                                             passContext: processResult.passContext)

    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  // MARK: Top Level Members
  func visit(_ contractMember: ContractMember, passContext: ASTPassContext) -> ASTPassResult<ContractMember> {
    var processResult = pass.process(contractMember: contractMember, passContext: passContext)

    switch processResult.element {
    case .variableDeclaration(let variableDeclaration):
      processResult.element =
        .variableDeclaration(processResult.combining(visit(variableDeclaration,
                                                           passContext: processResult.passContext)))
    case .eventDeclaration(let eventDeclaration):
      processResult.element =
        .eventDeclaration(processResult.combining(visit(eventDeclaration,
                                                        passContext: processResult.passContext)))
    }

    let postProcessResult = pass.postProcess(contractMember: processResult.element,
                                             passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)

  }

  func visit(_ structMember: StructMember, passContext: ASTPassContext) -> ASTPassResult<StructMember> {
    var processResult = pass.process(structMember: structMember, passContext: passContext)

    switch processResult.element {
    case .functionDeclaration(let functionDeclaration):
      processResult.element =
        .functionDeclaration(processResult.combining(visit(functionDeclaration,
                                                           passContext: processResult.passContext)))
    case .variableDeclaration(let variableDeclaration):
      processResult.element =
        .variableDeclaration(processResult.combining(visit(variableDeclaration,
                                                           passContext: processResult.passContext)))
    case .specialDeclaration(let specialDeclaration):
      processResult.element =
        .specialDeclaration(processResult.combining(visit(specialDeclaration,
                                                          passContext: processResult.passContext)))
    }

    let postProcessResult = pass.postProcess(structMember: processResult.element,
                                             passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ enumCase: EnumMember, passContext: ASTPassContext) -> ASTPassResult<EnumMember> {
    var processResult = pass.process(enumMember: enumCase, passContext: passContext)

    processResult.element.identifier =
      processResult.combining(visit(processResult.element.identifier,
                                    passContext: processResult.passContext))

    let postProcessResult = pass.postProcess(enumMember: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ traitMember: TraitMember, passContext: ASTPassContext) -> ASTPassResult<TraitMember> {
    var processResult = pass.process(traitMember: traitMember, passContext: passContext)

    switch processResult.element {
    case .functionDeclaration(let functionDeclaration):
      processResult.element =
        .functionDeclaration(processResult.combining(visit(functionDeclaration,
                                                           passContext: processResult.passContext)))
    case .functionSignatureDeclaration(let functionSignatureDeclaration):
      processResult.element = .
        functionSignatureDeclaration(processResult.combining(visit(functionSignatureDeclaration,
                                                                   passContext: processResult.passContext)))
    case .specialDeclaration(let specialDeclaration):
      processResult.element =
        .specialDeclaration(processResult.combining(visit(specialDeclaration,
                                                          passContext: processResult.passContext)))
    case .specialSignatureDeclaration(let specialSignatureDeclaration):
      processResult.element =
        .specialSignatureDeclaration(processResult.combining(visit(specialSignatureDeclaration,
                                                                   passContext: processResult.passContext)))
    case .contractBehaviourDeclaration(let contractBehaviourDeclaration):
      processResult.element =
        .contractBehaviourDeclaration(processResult.combining(visit(contractBehaviourDeclaration,
                                                                    passContext: processResult.passContext)))
    case .eventDeclaration(let eventDeclaration):
      processResult.element =
        .eventDeclaration(processResult.combining(visit(eventDeclaration,
                                                        passContext: processResult.passContext)))
    }

    let postProcessResult = pass.postProcess(traitMember: processResult.element, passContext: processResult.passContext)

    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ contractBehaviorMember: ContractBehaviorMember,
             passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorMember> {
    var processResult = pass.process(contractBehaviorMember: contractBehaviorMember, passContext: passContext)

    switch processResult.element {
    case .functionDeclaration(let decl):
      processResult.element =
        .functionDeclaration(processResult.combining(visit(decl, passContext: processResult.passContext)))
    case .specialDeclaration(let decl):
      processResult.element =
        .specialDeclaration(processResult.combining(visit(decl, passContext: processResult.passContext)))
    case .functionSignatureDeclaration(let decl):
      processResult.element =
        .functionSignatureDeclaration(processResult.combining(visit(decl, passContext: processResult.passContext)))
    case .specialSignatureDeclaration(let decl):
      processResult.element =
        .specialSignatureDeclaration(processResult.combining(visit(decl, passContext: processResult.passContext)))
    }

    let postProcessResult = pass.postProcess(contractBehaviorMember: processResult.element,
                                             passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  // MARK: Statements
  func visit(_ statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    var processResult = pass.process(statement: statement, passContext: passContext)

    switch processResult.element {
    case .expression(let expression):
      processResult.element =
        .expression(processResult.combining(visit(expression, passContext: processResult.passContext)))
    case .returnStatement(let returnStatement):
      processResult.element =
        .returnStatement(processResult.combining(visit(returnStatement, passContext: processResult.passContext)))
    case .becomeStatement(let becomeStatement):
      processResult.element =
        .becomeStatement(processResult.combining(visit(becomeStatement, passContext: processResult.passContext)))
    case .ifStatement(let ifStatement):
      processResult.element =
        .ifStatement(processResult.combining(visit(ifStatement, passContext: processResult.passContext)))
    case .forStatement(let forStatement):
      processResult.element =
        .forStatement(processResult.combining(visit(forStatement, passContext: processResult.passContext)))
    case .emitStatement(let emitStatement):
      processResult.element =
        .emitStatement(processResult.combining(visit(emitStatement, passContext: processResult.passContext)))
    case .doCatchStatement(let doCatchStatement):
      processResult.element =
        .doCatchStatement(processResult.combining(visit(doCatchStatement, passContext: processResult.passContext)))
    }
    let postProcessResult = pass.postProcess(statement: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    var processResult = pass.process(returnStatement: returnStatement, passContext: passContext)

    if let expression = processResult.element.expression {
      processResult.element.expression =
        processResult.combining(visit(expression, passContext: processResult.passContext))
    }

    let postProcessResult = pass.postProcess(returnStatement: processResult.element,
                                             passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ becomeStatement: BecomeStatement, passContext: ASTPassContext) -> ASTPassResult<BecomeStatement> {
    var processResult = pass.process(becomeStatement: becomeStatement, passContext: passContext)

    processResult.passContext.isInBecome = true
    processResult.element.expression =
      processResult.combining(visit(processResult.element.expression,
                                    passContext: processResult.passContext))
    processResult.passContext.isInBecome = false

    let postProcessResult = pass.postProcess(becomeStatement: processResult.element,
                                             passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ emitStatement: EmitStatement, passContext: ASTPassContext) -> ASTPassResult<EmitStatement> {
    var processResult = pass.process(emitStatement: emitStatement, passContext: passContext)

    processResult.passContext.isInEmit = true
    processResult.element.functionCall =
      processResult.combining(visit(processResult.element.functionCall,
                                    passContext: processResult.passContext))
    processResult.passContext.isInEmit = false

    let postProcessResult =
      pass.postProcess(emitStatement: processResult.element,
                       passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    var passContext = passContext
    var processResult = pass.process(ifStatement: ifStatement, passContext: passContext)

    processResult.passContext.isInsideIfCondition = true

    processResult.element.condition =
      processResult.combining(visit(processResult.element.condition,
                                    passContext: processResult.passContext))

    processResult.passContext.isInsideIfCondition = false

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
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ forStatement: ForStatement, passContext: ASTPassContext) -> ASTPassResult<ForStatement> {
    var passContext = passContext
    var processResult = pass.process(forStatement: forStatement, passContext: passContext)

    processResult.element.variable = processResult.combining(visit(processResult.element.variable,
                                                                   passContext: processResult.passContext))
    processResult.element.iterable = processResult.combining(visit(processResult.element.iterable,
                                                                   passContext: processResult.passContext))

    let scopeContext = passContext.scopeContext
    processResult.element.body = processResult.element.body.map { statement in
      return processResult.combining(visit(statement, passContext: processResult.passContext))
    }

    if processResult.element.forBodyScopeContext == nil {
      processResult.element.forBodyScopeContext = processResult.passContext.scopeContext
    }

    processResult.passContext.scopeContext = scopeContext

    let postProcessResult = pass.postProcess(forStatement: processResult.element,
                                             passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ doCatchStatement: DoCatchStatement, passContext: ASTPassContext) -> ASTPassResult<DoCatchStatement> {
    var passContext = passContext
    var processResult = pass.process(doCatchStatement: doCatchStatement, passContext: passContext)

    processResult.passContext = processResult.passContext.withUpdates {
      $0.doCatchStatementStack.append(doCatchStatement)
    }

    let scopeContext = passContext.scopeContext
    processResult.element.doBody = processResult.element.doBody.map { statement in
      return processResult.combining(visit(statement, passContext: processResult.passContext))
    }

    processResult.element.containsExternalCall =
      processResult.passContext.doCatchStatementStack.last!.containsExternalCall

    processResult.passContext = processResult.passContext.withUpdates {
      _ = $0.doCatchStatementStack.popLast()
    }

    processResult.passContext.scopeContext = scopeContext
    processResult.element.catchBody = processResult.element.catchBody.map { statement in
      return processResult.combining(visit(statement, passContext: processResult.passContext))
    }

    processResult.passContext.scopeContext = scopeContext
    let postProcessResult = pass.postProcess(doCatchStatement: processResult.element,
                                             passContext: processResult.passContext)

    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  // MARK: Declarations
  func visit(_ eventDeclaration: EventDeclaration, passContext: ASTPassContext) -> ASTPassResult<EventDeclaration> {
    var processResult = pass.process(eventDeclaration: eventDeclaration, passContext: passContext)

    let declarationContext = EventDeclarationContext(eventIdentifier: eventDeclaration.identifier)
    let scopeContext = ScopeContext()

    processResult.passContext = processResult.passContext.withUpdates {
      $0.eventDeclarationContext = declarationContext
      $0.scopeContext = scopeContext
    }

    processResult.element.identifier = processResult.combining(visit(processResult.element.identifier,
                                                                     passContext: processResult.passContext))

    processResult.element.variableDeclarations = processResult.element.variableDeclarations.map { variableDeclaration in
      return processResult.combining(visit(variableDeclaration, passContext: processResult.passContext))
    }

    processResult.passContext.eventDeclarationContext = nil
    processResult.passContext.scopeContext = nil

    let postProcessResult = pass.postProcess(eventDeclaration: processResult.element,
                                             passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ variableDeclaration: VariableDeclaration,
             passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    var processResult = pass.process(variableDeclaration: variableDeclaration, passContext: passContext)

    processResult.element.identifier = processResult.combining(visit(processResult.element.identifier,
                                                                     passContext: processResult.passContext))
    processResult.element.type = processResult.combining(visit(processResult.element.type,
                                                               passContext: processResult.passContext))

    if let assignedExpression = processResult.element.assignedExpression {
      let previousScopeContext = processResult.passContext.scopeContext
      // Create an empty scope context.
      processResult.passContext.scopeContext = ScopeContext()
      processResult.passContext.isPropertyDefaultAssignment = true
      processResult.element.assignedExpression = processResult.combining(visit(assignedExpression,
                                                                               passContext: processResult.passContext))
      processResult.passContext.isPropertyDefaultAssignment = false
      processResult.passContext.scopeContext = previousScopeContext
    }

    let postProcessResult = pass.postProcess(variableDeclaration: processResult.element,
                                             passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ functionDeclaration: FunctionDeclaration,
             passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    var processResult = pass.process(functionDeclaration: functionDeclaration, passContext: passContext)

    processResult.element.signature = processResult.combining(visit(processResult.element.signature,
                                                                    passContext: processResult.passContext))

    let functionDeclarationContext = FunctionDeclarationContext(declaration: functionDeclaration)

    processResult.passContext.functionDeclarationContext = functionDeclarationContext

    processResult.passContext.scopeContext!.parameters.append(contentsOf: functionDeclaration.signature.parameters)

    processResult.element.body = processResult.element.body.map { statement in
      return processResult.combining(visit(statement, passContext: processResult.passContext))
    }

    processResult.passContext.functionDeclarationContext = nil

    let postProcessResult = pass.postProcess(functionDeclaration: processResult.element,
                                             passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ functionSignatureDeclaration: FunctionSignatureDeclaration,
             passContext: ASTPassContext) -> ASTPassResult<FunctionSignatureDeclaration> {
    var processResult = pass.process(functionSignatureDeclaration: functionSignatureDeclaration,
                                     passContext: passContext)

    processResult.element.attributes = processResult.element.attributes.map { attribute in
      return processResult.combining(visit(attribute, passContext: processResult.passContext))
    }

    processResult.element.identifier = processResult.combining(visit(processResult.element.identifier,
                                                                     passContext: processResult.passContext))

    processResult.element.parameters = processResult.element.parameters.map { parameter in
      return processResult.combining(visit(parameter, passContext: processResult.passContext))
    }

    if let resultType = processResult.element.resultType {
      processResult.element.resultType = processResult.combining(visit(resultType,
                                                                       passContext: processResult.passContext))
    }

    let postProcessResult = pass.postProcess(functionSignatureDeclaration: processResult.element,
                                             passContext: processResult.passContext)

    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ specialDeclaration: SpecialDeclaration,
             passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    var processResult = pass.process(specialDeclaration: specialDeclaration, passContext: passContext)

    processResult.element.signature = processResult.combining(visit(processResult.element.signature,
                                                                    passContext: processResult.passContext))

    let specialDeclarationContext = SpecialDeclarationContext(declaration: specialDeclaration)
    processResult.passContext.specialDeclarationContext = specialDeclarationContext

    let functionDeclaration = specialDeclaration.asFunctionDeclaration
    processResult.passContext.scopeContext!.parameters.append(contentsOf: functionDeclaration.signature.parameters)

    var newBody = [Statement]()
    for statement in processResult.element.body {
      newBody.append(processResult.combining(visit(statement, passContext: processResult.passContext)))
    }
    processResult.element.body = newBody
    processResult.passContext.specialDeclarationContext = nil

    let postProcessResult = pass.postProcess(specialDeclaration: processResult.element,
                                             passContext: processResult.passContext)

    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ specialSignatureDeclaration: SpecialSignatureDeclaration,
             passContext: ASTPassContext) -> ASTPassResult<SpecialSignatureDeclaration> {
    var processResult = pass.process(specialSignatureDeclaration: specialSignatureDeclaration, passContext: passContext)

    processResult.element.attributes = processResult.element.attributes.map { attribute in
      return processResult.combining(visit(attribute, passContext: processResult.passContext))
    }

    processResult.element.parameters = processResult.element.parameters.map { parameter in
      return processResult.combining(visit(parameter, passContext: processResult.passContext))
    }

    let postProcessResult = pass.postProcess(specialSignatureDeclaration: processResult.element,
                                             passContext: processResult.passContext)

    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  // MARK: Expression
  func visit(_ expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression> {
    var processResult = pass.process(expression: expression, passContext: passContext)

    switch processResult.element {
    case .inoutExpression(let inoutExpression):
      processResult.element = .inoutExpression(processResult.combining(visit(inoutExpression,
                                                                             passContext: processResult.passContext)))
    case .typeConversionExpression(let typeConversionExpression):
      processResult.element = .typeConversionExpression(
        processResult.combining(visit(typeConversionExpression, passContext: processResult.passContext)))

    case .binaryExpression(let binaryExpression):
      processResult.element = .binaryExpression(processResult.combining(visit(binaryExpression,
                                                                              passContext: processResult.passContext)))
    case .bracketedExpression(let bracketedExpression):
      processResult.element = .bracketedExpression(BracketedExpression(
        expression: processResult.combining(visit(bracketedExpression.expression,
                                                  passContext: processResult.passContext)),
        openBracketToken: bracketedExpression.openBracketToken,
        closeBracketToken: bracketedExpression.closeBracketToken
      ))
    case .functionCall(let functionCall):
      processResult.element = .functionCall(processResult.combining(visit(functionCall,
                                                                          passContext: processResult.passContext)))
    case .externalCall(let externalCall):
      processResult.element = .externalCall(processResult.combining(visit(externalCall,
                                                                          passContext: processResult.passContext)))
    case .arrayLiteral(let arrayLiteral):
      processResult.element = .arrayLiteral(processResult.combining(visit(arrayLiteral,
                                                                          passContext: processResult.passContext)))
    case .range(let rangeExpression):
      processResult.element = .range(processResult.combining(visit(rangeExpression,
                                                                   passContext: processResult.passContext)))
    case .dictionaryLiteral(let dictionaryLiteral):
      processResult.element = .dictionaryLiteral(processResult.combining(visit(dictionaryLiteral,
                                                                               passContext: processResult.passContext)))
    case .identifier(let identifier):
      processResult.element = .identifier(processResult.combining(visit(identifier,
                                                                        passContext: processResult.passContext)))
    case .literal(let literalToken):
      processResult.element = .literal(processResult.combining(visit(literalToken,
                                                                     passContext: processResult.passContext)))
    case .self: break
    case .variableDeclaration(let variableDeclaration):
      processResult.element =
        .variableDeclaration(processResult.combining(visit(variableDeclaration,
                                                           passContext: processResult.passContext)))
    case .subscriptExpression(let subscriptExpression):
      processResult.element =
        .subscriptExpression(processResult.combining(visit(subscriptExpression,
                                                           passContext: processResult.passContext)))
    case .attemptExpression(let attemptExpression):
      processResult.element = .attemptExpression(processResult.combining(visit(attemptExpression,
                                                                               passContext: processResult.passContext)))
    case .sequence(let elements):
      processResult.element = .sequence(elements.map { element in
        return processResult.combining(visit(element, passContext: processResult.passContext))
      })
    case .rawAssembly: break
    }

    let postProcessResult = pass.postProcess(expression: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ inoutExpression: InoutExpression, passContext: ASTPassContext) -> ASTPassResult<InoutExpression> {
    var processResult = pass.process(inoutExpression: inoutExpression, passContext: passContext)
    processResult.element.expression = processResult.combining(visit(processResult.element.expression,
                                                                     passContext: processResult.passContext))

    let postProcessResult = pass.postProcess(inoutExpression: processResult.element,
                                             passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
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

    let oldExternalContext = processResult.passContext.externalCallContext
    processResult.passContext.externalCallContext = nil
    processResult.element.lhs = processResult.combining(visit(processResult.element.lhs,
                                                              passContext: processResult.passContext))
    processResult.passContext.externalCallContext = oldExternalContext

    if !binaryExpression.isExplicitPropertyAccess {
      processResult.passContext.asLValue = false
    }
    processResult.passContext.isEnclosing = false

    switch passContext.environment!.type(of: processResult.element.lhs,
                                         enclosingType: passContext.enclosingTypeIdentifier!.name,
                                         scopeContext: passContext.scopeContext!) {
    case .arrayType, .fixedSizeArrayType, .dictionaryType:
      break
    default:
      if case .punctuation(let punctuation) = binaryExpression.op.kind, punctuation.isAssignment {
        processResult.passContext.inAssignment = true
      }
      if case .variableDeclaration(let variableDeclaration) = binaryExpression.lhs, variableDeclaration.isConstant {
        processResult.passContext.isIfLetConstruct = processResult.passContext.isInsideIfCondition
      }
      processResult.element.rhs = processResult.combining(visit(processResult.element.rhs,
                                                                passContext: processResult.passContext))
      processResult.passContext.isIfLetConstruct = false
      processResult.passContext.inAssignment = false // Allowed as nested assignments do not exist.
    }

    let postProcessResult = pass.postProcess(binaryExpression: processResult.element,
                                             passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ typeConversionExpression: TypeConversionExpression,
             passContext: ASTPassContext) -> ASTPassResult<TypeConversionExpression> {
    var processResult = pass.process(typeConversionExpression: typeConversionExpression, passContext: passContext)

    processResult.element.expression = processResult.combining(visit(processResult.element.expression,
                                                                     passContext: passContext))
    processResult.element.type = processResult.combining(visit(processResult.element.type, passContext: passContext))

    let postProcessResult = pass.postProcess(typeConversionExpression: processResult.element,
                                             passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    var processResult = pass.process(functionCall: functionCall, passContext: passContext)

    processResult.passContext.isFunctionCall = true
    processResult.element.identifier = processResult.combining(visit(processResult.element.identifier,
                                                                     passContext: processResult.passContext))
    processResult.passContext.isFunctionCall = false

    let oldExternalContext = processResult.passContext.externalCallContext
    processResult.passContext.externalCallContext = nil

    processResult.element.arguments = processResult.element.arguments.map { argument in
      let paramVisit = visit(argument, passContext: processResult.passContext)
      return processResult.combining(paramVisit)
    }

    processResult.passContext.externalCallContext = oldExternalContext

    let postProcessResult = pass.postProcess(functionCall: processResult.element,
                                             passContext: processResult.passContext)

    processResult.passContext.externalCallContext = nil

    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ externalCall: ExternalCall, passContext: ASTPassContext) -> ASTPassResult<ExternalCall> {
    var processResult = pass.process(externalCall: externalCall, passContext: passContext)

    processResult.passContext.isExternalConfigurationParam = true
    processResult.element.hyperParameters = processResult.element.hyperParameters.map { param in
      let paramVisit = visit(param, passContext: processResult.passContext)
      return processResult.combining(paramVisit)
    }
    processResult.passContext.isExternalConfigurationParam = false

    // for nested external calls
    let oldIsExternalCall = processResult.passContext.isExternalFunctionCall
    let oldExternalCallContext = processResult.passContext.externalCallContext

    processResult.passContext.isExternalFunctionCall = true
    processResult.passContext.externalCallContext = processResult.element

    processResult.element.functionCall = processResult.combining(visit(processResult.element.functionCall,
                                                                       passContext: processResult.passContext))
    processResult.passContext.externalCallContext = oldExternalCallContext
    processResult.passContext.isExternalFunctionCall = oldIsExternalCall

    let postProcessResult = pass.postProcess(externalCall: processResult.element,
                                             passContext: processResult.passContext)

    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ rangeExpression: RangeExpression, passContext: ASTPassContext) -> ASTPassResult<RangeExpression> {
    var processResult = pass.process(rangeExpression: rangeExpression, passContext: passContext)
    var element = processResult.element
    element.initial = processResult.combining(visit(element.initial, passContext: processResult.passContext))
    element.bound = processResult.combining(visit(element.bound, passContext: processResult.passContext))

    let postProcessResult = pass.postProcess(rangeExpression: element, passContext: processResult.passContext)
    return ASTPassResult(element: element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ subscriptExpression: SubscriptExpression,
             passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    var processResult = pass.process(subscriptExpression: subscriptExpression, passContext: passContext)
    let inSubscript = processResult.passContext.isInSubscript

    processResult.element.baseExpression = processResult.combining(visit(processResult.element.baseExpression,
                                                                         passContext: processResult.passContext))

    processResult.passContext.isInSubscript = true
    processResult.element.indexExpression = processResult.combining(visit(processResult.element.indexExpression,
                                                                          passContext: processResult.passContext))
    processResult.passContext.isInSubscript = inSubscript

    let postProcessResult = pass.postProcess(subscriptExpression: processResult.element,
                                             passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ attemptExpression: AttemptExpression, passContext: ASTPassContext) -> ASTPassResult<AttemptExpression> {
    var processResult = pass.process(attemptExpression: attemptExpression, passContext: passContext)

    processResult.element.functionCall =
      processResult.combining(visit(processResult.element.functionCall,
                                    passContext: processResult.passContext))

    let postProcessResult = pass.postProcess(attemptExpression: processResult.element,
                                             passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ arrayLiteral: ArrayLiteral, passContext: ASTPassContext) -> ASTPassResult<ArrayLiteral> {
    var processResult = pass.process(arrayLiteral: arrayLiteral, passContext: passContext)

    processResult.element.elements = processResult.element.elements.map { element in
      return processResult.combining(visit(element, passContext: processResult.passContext))
    }

    let postProcessResult = pass.postProcess(arrayLiteral: processResult.element,
                                             passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ dictionaryLiteral: DictionaryLiteral, passContext: ASTPassContext) -> ASTPassResult<DictionaryLiteral> {
    var processResult = pass.process(dictionaryLiteral: dictionaryLiteral, passContext: passContext)

    processResult.element.elements = processResult.element.elements.map { element in
      var element = element
      element.key = processResult.combining(visit(element.key, passContext: processResult.passContext))
      element.value = processResult.combining(visit(element.value, passContext: processResult.passContext))
      return element
    }

    let postProcessResult = pass.postProcess(dictionaryLiteral: processResult.element,
                                             passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  // MARK: Components
  func visit(_ attribute: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute> {
    let processResult = pass.process(attribute: attribute, passContext: passContext)

    let postProcessResult = pass.postProcess(attribute: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ parameter: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter> {
    var processResult = pass.process(parameter: parameter, passContext: passContext)
    processResult.element.type = processResult.combining(visit(processResult.element.type,
                                                               passContext: processResult.passContext))

    let postProcessResult = pass.postProcess(parameter: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier> {
    let processResult = pass.process(identifier: identifier, passContext: passContext)
    let postProcessResult = pass.postProcess(identifier: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ type: Type, passContext: ASTPassContext) -> ASTPassResult<Type> {
    var processResult = pass.process(type: type, passContext: passContext)

    processResult.element.genericArguments = processResult.element.genericArguments.map { genericArgument in
      return processResult.combining(visit(genericArgument, passContext: processResult.passContext))
    }

    let postProcessResult = pass.postProcess(type: processResult.element, passContext: passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ callerProtection: CallerProtection, passContext: ASTPassContext) -> ASTPassResult<CallerProtection> {
    var processResult = pass.process(callerProtection: callerProtection, passContext: passContext)

    processResult.element.identifier = processResult.combining(visit(processResult.element.identifier,
                                                                     passContext: processResult.passContext))

    let postProcessResult = pass.postProcess(callerProtection: processResult.element,
                                             passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ typeState: TypeState, passContext: ASTPassContext) -> ASTPassResult<TypeState> {
    var processResult = pass.process(typeState: typeState, passContext: passContext)

    processResult.element.identifier = processResult.combining(visit(processResult.element.identifier,
                                                                     passContext: processResult.passContext))

    let postProcessResult = pass.postProcess(typeState: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ conformance: Conformance, passContext: ASTPassContext) -> ASTPassResult<Conformance> {
    var processResult = pass.process(conformance: conformance, passContext: passContext)

    processResult.element.identifier = processResult.combining(visit(processResult.element.identifier,
                                                                     passContext: processResult.passContext))

    let postProcessResult = pass.postProcess(conformance: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }

  func visit(_ literalToken: Token, passContext: ASTPassContext) -> ASTPassResult<Token> {
    let processResult = pass.process(token: literalToken, passContext: passContext)
    let postProcessResult = pass.process(token: processResult.element, passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: postProcessResult.diagnostics,
                         passContext: passContext)
  }

  func visit(_ functionArgument: FunctionArgument, passContext: ASTPassContext) -> ASTPassResult<FunctionArgument> {
    var processResult = pass.process(functionArgument: functionArgument, passContext: passContext)

    processResult.passContext.isFunctionCallArgumentLabel = true
    if let identifier = processResult.element.identifier {
      processResult.element.identifier = processResult.combining(visit(identifier,
                                                                       passContext: processResult.passContext))
    }
    processResult.passContext.isFunctionCallArgumentLabel = false

    processResult.passContext.isFunctionCallArgument = true
    processResult.element.expression = processResult.combining(visit(processResult.element.expression,
                                                                     passContext: processResult.passContext))
    processResult.passContext.isFunctionCallArgument = false

    let postProcessResult = pass.postProcess(functionArgument: processResult.element,
                                             passContext: processResult.passContext)
    return ASTPassResult(element: postProcessResult.element,
                         diagnostics: processResult.diagnostics + postProcessResult.diagnostics,
                         passContext: postProcessResult.passContext)
  }
}
