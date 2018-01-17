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
    var result = pass.process(element: topLevelModule, passContext: passContext)

    result.element.declarations = result.element.declarations.map { declaration in
      result.mergingDiagnostics(visit(declaration, passContext: result.passContext))
    }

    return ASTPassResult(element: result.element, diagnostics: result.diagnostics, passContext: result.passContext)
  }

  func visit(_ topLevelDeclaration: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration> {
    var result = pass.process(element: topLevelDeclaration, passContext: passContext)
    
    switch result.element {
    case .contractBehaviorDeclaration(let contractBehaviorDeclaration):
      _ = result.mergingDiagnostics(visit(contractBehaviorDeclaration, passContext: result.passContext))
    case .contractDeclaration(let contractDeclaration):
      _ = result.mergingDiagnostics(visit(contractDeclaration, passContext: result.passContext))
    }
    return ASTPassResult(element: result.element, diagnostics: result.diagnostics, passContext: result.passContext)
  }

  func visit(_ contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    var result = pass.process(element: contractDeclaration, passContext: passContext)

    result.element.identifier = result.mergingDiagnostics(visit(result.element.identifier, passContext: result.passContext))
    result.element.variableDeclarations = result.element.variableDeclarations.map { variableDeclaration in
      return result.mergingDiagnostics(visit(variableDeclaration, passContext: result.passContext))
    }

    return ASTPassResult(element: result.element, diagnostics: result.diagnostics, passContext: result.passContext)
  }

  func visit(_ contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    var result = pass.process(element: contractBehaviorDeclaration, passContext: passContext)

    result.element.contractIdentifier = result.mergingDiagnostics(visit(result.element.contractIdentifier, passContext: result.passContext))

    if let capabilityBinding = result.element.capabilityBinding {
      result.element.capabilityBinding = result.mergingDiagnostics(visit(capabilityBinding, passContext: result.passContext))
    }

    result.element.callerCapabilities = result.element.callerCapabilities.map { callerCapability in
      return result.mergingDiagnostics(visit(callerCapability, passContext: result.passContext))
    }

    result.element.functionDeclarations = result.element.functionDeclarations.map { functionDeclaration in
      return result.mergingDiagnostics(visit(functionDeclaration, passContext: result.passContext))
    }

    return ASTPassResult(element: result.element, diagnostics: result.diagnostics, passContext: result.passContext)
  }

  func visit(_ variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    var result = pass.process(element: variableDeclaration, passContext: passContext)

    result.element.identifier = result.mergingDiagnostics(visit(result.element.identifier, passContext: result.passContext))
    result.element.type = result.mergingDiagnostics(visit(result.element.type, passContext: result.passContext))

    return ASTPassResult(element: result.element, diagnostics: result.diagnostics, passContext: result.passContext)
  }

  func visit(_ functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    var result = pass.process(element: functionDeclaration, passContext: passContext)

    result.element.attributes = result.element.attributes.map { attribute in
      return result.mergingDiagnostics(visit(attribute, passContext: result.passContext))
    }

    result.element.identifier = result.mergingDiagnostics(visit(result.element.identifier, passContext: result.passContext))
    result.element.parameters = result.element.parameters.map { parameter in
      return result.mergingDiagnostics(visit(parameter, passContext: result.passContext))
    }

    if let resultType = result.element.resultType {
      result.element.resultType = result.mergingDiagnostics(visit(resultType, passContext: result.passContext))
    }

    result.element.body = result.element.body.map { statement in
      return result.mergingDiagnostics(visit(statement, passContext: result.passContext))
    }

    return ASTPassResult(element: result.element, diagnostics: result.diagnostics, passContext: result.passContext)
  }

  func visit(_ attribute: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute> {
    let result = pass.process(element: attribute, passContext: passContext)
    return ASTPassResult(element: result.element, diagnostics: result.diagnostics, passContext: result.passContext)
  }

  func visit(_ parameter: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter> {
    var result = pass.process(element: parameter, passContext: passContext)
    result.element.type = result.mergingDiagnostics(visit(result.element.type, passContext: result.passContext))
    return ASTPassResult(element: result.element, diagnostics: result.diagnostics, passContext: result.passContext)
  }

  func visit(_ typeAnnotation: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation> {
    var result = pass.process(element: typeAnnotation, passContext: passContext)
    result.element.type = result.mergingDiagnostics(visit(result.element.type, passContext: result.passContext))
    return ASTPassResult(element: result.element, diagnostics: result.diagnostics, passContext: result.passContext)
  }

  func visit(_ identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier> {
    let result = pass.process(element: identifier, passContext: passContext)
    return ASTPassResult(element: result.element, diagnostics: result.diagnostics, passContext: result.passContext)
  }

  func visit(_ type: Type, passContext: ASTPassContext) -> ASTPassResult<Type> {
    var result = pass.process(element: type, passContext: passContext)

    result.element.genericArguments = result.element.genericArguments.map { genericArgument in
      return result.mergingDiagnostics(visit(genericArgument, passContext: result.passContext))
    }

    return ASTPassResult(element: result.element, diagnostics: result.diagnostics, passContext: result.passContext)
  }

  func visit(_ callerCapability: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability> {
    var result = pass.process(element: callerCapability, passContext: passContext)

    result.element.identifier = result.mergingDiagnostics(visit(result.element.identifier, passContext: result.passContext))

    return ASTPassResult(element: result.element, diagnostics: result.diagnostics, passContext: result.passContext)
  }

  func visit(_ expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression> {
    var result = pass.process(element: expression, passContext: passContext)

    switch result.element {
    case .binaryExpression(let binaryExpression):
      _ = result.mergingDiagnostics(visit(binaryExpression, passContext: result.passContext))
    case .bracketedExpression(let expression):
      _ = result.mergingDiagnostics(visit(expression, passContext: result.passContext))
    case .functionCall(let functionCall):
      _ = result.mergingDiagnostics(visit(functionCall, passContext: result.passContext))
    case .identifier(let identifier):
      _ = result.mergingDiagnostics(visit(identifier, passContext: result.passContext))
    case .literal(_), .self(_): break
    case .variableDeclaration(let variableDeclaration):
      _ = result.mergingDiagnostics(visit(variableDeclaration, passContext: result.passContext))
    case .subscriptExpression(let subscriptExpression):
      _ = result.mergingDiagnostics(visit(subscriptExpression, passContext: result.passContext))
    }

    return result
  }

  func visit(_ statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    var result = pass.process(element: statement, passContext: passContext)

    switch result.element {
    case .expression(let expression):
      _ = result.mergingDiagnostics(visit(expression, passContext: result.passContext))
    case .returnStatement(let returnStatement):
      _ = result.mergingDiagnostics(visit(returnStatement, passContext: result.passContext))
    case .ifStatement(let ifStatement):
      _ = result.mergingDiagnostics(visit(ifStatement, passContext: result.passContext))
    }
    return ASTPassResult(element: result.element, diagnostics: result.diagnostics, passContext: result.passContext)
  }

  func visit(_ binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    var result = pass.process(element: binaryExpression, passContext: passContext)

    result.element.lhs = result.mergingDiagnostics(visit(result.element.lhs, passContext: result.passContext))
    result.element.rhs = result.mergingDiagnostics(visit(result.element.rhs, passContext: result.passContext))

    return ASTPassResult(element: result.element, diagnostics: result.diagnostics, passContext: result.passContext)
  }

  func visit(_ functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    var result = pass.process(element: functionCall, passContext: passContext)

    result.element.identifier = result.mergingDiagnostics(visit(result.element.identifier, passContext: result.passContext))
    result.element.arguments = result.element.arguments.map { argument in
      return result.mergingDiagnostics(visit(argument, passContext: result.passContext))
    }

    return ASTPassResult(element: result.element, diagnostics: result.diagnostics, passContext: result.passContext)
  }

  func visit(_ subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    var result = pass.process(element: subscriptExpression, passContext: passContext)

    result.element.baseIdentifier = result.mergingDiagnostics(visit(result.element.baseIdentifier, passContext: result.passContext))

    result.element.indexExpression = result.mergingDiagnostics(visit(result.element.indexExpression, passContext: result.passContext))

    return ASTPassResult(element: result.element, diagnostics: result.diagnostics, passContext: result.passContext)
  }

  func visit(_ returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    var result = pass.process(element: returnStatement, passContext: passContext)

    if let expression = result.element.expression {
      result.element.expression = result.mergingDiagnostics(visit(expression, passContext: result.passContext))
    }

    return ASTPassResult(element: result.element, diagnostics: result.diagnostics, passContext: result.passContext)
  }

  func visit(_ ifStatament: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    var result = pass.process(element: ifStatament, passContext: passContext)

    result.element.condition = result.mergingDiagnostics(visit(result.element.condition, passContext: result.passContext))

    result.element.body = result.element.body.map { statement in
      return result.mergingDiagnostics(visit(statement, passContext: result.passContext))
    }

    result.element.elseBody = result.element.body.map { statement in
      return result.mergingDiagnostics(visit(statement, passContext: result.passContext))
    }

    return ASTPassResult(element: result.element, diagnostics: result.diagnostics, passContext: result.passContext)
  }
}

//private enum TokenUnion {
//  case topLevelModule(TopLevelModule)
//  case topLevelDeclaration(TopLevelDeclaration)
//  case contractDeclaration(ContractDeclaration)
//  case contractBehaviorDeclaration(ContractBehaviorDeclaration)
//  case variableDeclaration(VariableDeclaration)
//  case functionDeclaration(FunctionDeclaration)
//  case attribute(Attribute)
//  case parameter(Parameter)
//  case typeAnnotation(TypeAnnotation)
//  case identifier(Identifier)
//  case type(Type)
//  case callerCapability(CallerCapability)
//  case expression(Expression)
//  case statement(Statement)
//  case binaryExpression(BinaryExpression)
//  case functionCall(FunctionCall)
//  case subscriptExpression(SubscriptExpression)
//  case returnStatement(ReturnStatement)
//  case ifStatement(IfStatement)
//
//  init?(node: Any) {
//    switch node {
//    case let topLevelModule as TopLevelModule: self = .topLevelModule(topLevelModule)
//    case let topLevelDeclaration as TopLevelDeclaration: self = .topLevelDeclaration(topLevelDeclaration)
//    case let contractDeclaration as ContractDeclaration: self = .contractDeclaration(contractDeclaration)
//    case let contractBehaviorDeclaration as ContractBehaviorDeclaration: self = .contractBehaviorDeclaration(contractBehaviorDeclaration)
//    case let variableDeclaration as VariableDeclaration: self = .variableDeclaration(variableDeclaration)
//    case let functionDeclaration as FunctionDeclaration: self = .functionDeclaration(functionDeclaration)
//    case let attribute as Attribute: self = .attribute(attribute)
//    case let parameter as Parameter: self = .parameter(parameter)
//    case let typeAnnotation as TypeAnnotation: self = .typeAnnotation(typeAnnotation)
//    case let identifier as Identifier: self = .identifier(identifier)
//    case let type as Type: self = .type(type)
//    case let callerCapability as CallerCapability: self = .callerCapability(callerCapability)
//    case let expression as Expression: self = .expression(expression)
//    case let statement as Statement: self = .statement(statement)
//    case let binaryExpression as BinaryExpression: self = .binaryExpression(binaryExpression)
//    case let functionCall as FunctionCall: self = .functionCall(functionCall)
//    case let subscriptExpression as SubscriptExpression: self = .subscriptExpression(subscriptExpression)
//    case let returnStatement as ReturnStatement: self = .returnStatement(returnStatement)
//    case let ifStatement as IfStatement: self = .ifStatement(ifStatement)
//    default: fatalError()
//    }
//  }
//}

