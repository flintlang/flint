//
//  ASTPass.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 1/11/18.
//

public protocol ASTPass {
  func preProcess(topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule>
  func preProcess(topLevelDeclaration: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration>
  func preProcess(contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration>
  func preProcess(contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration>
  func preProcess(variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration>
  func preProcess(functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration>
  func preProcess(attribute: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute>
  func preProcess(parameter: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter>
  func preProcess(typeAnnotation: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation>
  func preProcess(identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier>
  func preProcess(type: Type, passContext: ASTPassContext) -> ASTPassResult<Type>
  func preProcess(callerCapability: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability>
  func preProcess(expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression>
  func preProcess(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement>
  func preProcess(binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression>
  func preProcess(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall>
  func preProcess(subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression>
  func preProcess(returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement>
  func preProcess(ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement>

  func postProcess(topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule>
  func postProcess(topLevelDeclaration: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration>
  func postProcess(contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration>
  func postProcess(contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration>
  func postProcess(variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration>
  func postProcess(functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration>
  func postProcess(attribute: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute>
  func postProcess(parameter: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter>
  func postProcess(typeAnnotation: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation>
  func postProcess(identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier>
  func postProcess(type: Type, passContext: ASTPassContext) -> ASTPassResult<Type>
  func postProcess(callerCapability: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability>
  func postProcess(expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression>
  func postProcess(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement>
  func postProcess(binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression>
  func postProcess(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall>
  func postProcess(subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression>
  func postProcess(returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement>
  func postProcess(ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement>
}

public struct AnyASTPass: ASTPass {
  var base: ASTPass

  public init(_ base: ASTPass) {
    self.base = base
  }

  public func preProcess(topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule> {
    return base.preProcess(topLevelModule: topLevelModule, passContext: passContext)
  }

  public func preProcess(topLevelDeclaration: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration> {
    return base.preProcess(topLevelDeclaration: topLevelDeclaration, passContext: passContext)
  }

  public func preProcess(contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    return base.preProcess(contractDeclaration: contractDeclaration, passContext: passContext)
  }

  public func preProcess(contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    return base.preProcess(contractBehaviorDeclaration: contractBehaviorDeclaration, passContext: passContext)
  }

  public func preProcess(variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    return base.preProcess(variableDeclaration: variableDeclaration, passContext: passContext)
  }

  public func preProcess(functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    return base.preProcess(functionDeclaration: functionDeclaration, passContext: passContext)
  }

  public func preProcess(attribute: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute> {
    return base.preProcess(attribute: attribute, passContext: passContext)
  }

  public func preProcess(parameter: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter> {
    return base.preProcess(parameter: parameter, passContext: passContext)
  }

  public func preProcess(typeAnnotation: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation> {
    return base.preProcess(typeAnnotation: typeAnnotation, passContext: passContext)
  }

  public func preProcess(identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier> {
    return base.preProcess(identifier: identifier, passContext: passContext)
  }

  public func preProcess(type: Type, passContext: ASTPassContext) -> ASTPassResult<Type> {
    return base.preProcess(type: type, passContext: passContext)
  }

  public func preProcess(callerCapability: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability> {
    return base.preProcess(callerCapability: callerCapability, passContext: passContext)
  }

  public func preProcess(expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression> {
    return base.preProcess(expression: expression, passContext: passContext)
  }

  public func preProcess(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    return base.preProcess(statement: statement, passContext: passContext)
  }

  public func preProcess(binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    return base.preProcess(binaryExpression: binaryExpression, passContext: passContext)
  }

  public func preProcess(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    return base.preProcess(functionCall: functionCall, passContext: passContext)
  }

  public func preProcess(subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    return base.preProcess(subscriptExpression: subscriptExpression, passContext: passContext)
  }


  public func preProcess(returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    return base.preProcess(returnStatement: returnStatement, passContext: passContext)
  }

  public func preProcess(ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    return base.preProcess(ifStatement: ifStatement, passContext: passContext)
  }

  public func postProcess(topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule> {
    return base.postProcess(topLevelModule: topLevelModule, passContext: passContext)
  }

  public func postProcess(topLevelDeclaration: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration> {
    return base.postProcess(topLevelDeclaration: topLevelDeclaration, passContext: passContext)
  }

  public func postProcess(contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    return base.postProcess(contractDeclaration: contractDeclaration, passContext: passContext)
  }

  public func postProcess(contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    return base.postProcess(contractBehaviorDeclaration: contractBehaviorDeclaration, passContext: passContext)
  }

  public func postProcess(variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    return base.postProcess(variableDeclaration: variableDeclaration, passContext: passContext)
  }

  public func postProcess(functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    return base.postProcess(functionDeclaration: functionDeclaration, passContext: passContext)
  }

  public func postProcess(attribute: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute> {
    return base.postProcess(attribute: attribute, passContext: passContext)
  }

  public func postProcess(parameter: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter> {
    return base.postProcess(parameter: parameter, passContext: passContext)
  }

  public func postProcess(typeAnnotation: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation> {
    return base.postProcess(typeAnnotation: typeAnnotation, passContext: passContext)
  }

  public func postProcess(identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier> {
    return base.postProcess(identifier: identifier, passContext: passContext)
  }

  public func postProcess(type: Type, passContext: ASTPassContext) -> ASTPassResult<Type> {
    return base.postProcess(type: type, passContext: passContext)
  }

  public func postProcess(callerCapability: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability> {
    return base.postProcess(callerCapability: callerCapability, passContext: passContext)
  }

  public func postProcess(expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression> {
    return base.postProcess(expression: expression, passContext: passContext)
  }

  public func postProcess(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    return base.postProcess(statement: statement, passContext: passContext)
  }

  public func postProcess(binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    return base.postProcess(binaryExpression: binaryExpression, passContext: passContext)
  }

  public func postProcess(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    return base.postProcess(functionCall: functionCall, passContext: passContext)
  }

  public func postProcess(subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    return base.postProcess(subscriptExpression: subscriptExpression, passContext: passContext)
  }


  public func postProcess(returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    return base.postProcess(returnStatement: returnStatement, passContext: passContext)
  }

  public func postProcess(ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    return base.postProcess(ifStatement: ifStatement, passContext: passContext)
  }
}
