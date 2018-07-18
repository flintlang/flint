//
//  ASTPass.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 1/11/18.
//

/// A pass over an AST.
///
/// The class `ASTVisitor` is used to visit an AST using a given `ASTPass`. The appropriate `process` function will be
/// called when visiting a node, and `postProcess` will be called after visiting the children of that node.
public protocol ASTPass {
  func process(topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule>
  func process(topLevelDeclaration: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration>
  func process(contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration>
  func process(structDeclaration: StructDeclaration, passContext: ASTPassContext) -> ASTPassResult<StructDeclaration>
  func process(structMember: StructMember, passContext: ASTPassContext) -> ASTPassResult<StructMember>
  func process(contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration>
  func process(contractBehaviorMember: ContractBehaviorMember, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorMember>
  func process(variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration>
  func process(functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration>
  func process(specialDeclaration: SpecialDeclaration, passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration>
  func process(attribute: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute>
  func process(parameter: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter>
  func process(typeAnnotation: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation>
  func process(identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier>
  func process(type: Type, passContext: ASTPassContext) -> ASTPassResult<Type>
  func process(callerCapability: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability>
  func process(expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression>
  func process(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement>
  func process(inoutExpression: InoutExpression, passContext: ASTPassContext) -> ASTPassResult<InoutExpression>
  func process(binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression>
  func process(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall>
  func process(arrayLiteral: ArrayLiteral, passContext: ASTPassContext) -> ASTPassResult<ArrayLiteral>
  func process(rangeExpression: RangeExpression, passContext: ASTPassContext) -> ASTPassResult<RangeExpression>
  func process(dictionaryLiteral: DictionaryLiteral, passContext: ASTPassContext) -> ASTPassResult<DictionaryLiteral>
  func process(literalToken: Token, passContext: ASTPassContext) -> ASTPassResult<Token>
  func process(subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression>
  func process(returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement>
  func process(ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement>
  func process(forStatement: ForStatement, passContext: ASTPassContext) -> ASTPassResult<ForStatement>

  func postProcess(topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule>
  func postProcess(topLevelDeclaration: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration>
  func postProcess(contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration>
  func postProcess(structMember: StructMember, passContext: ASTPassContext) -> ASTPassResult<StructMember>
  func postProcess(contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration>
  func postProcess(contractBehaviorMember: ContractBehaviorMember, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorMember>
  func postProcess(structDeclaration: StructDeclaration, passContext: ASTPassContext) -> ASTPassResult<StructDeclaration>
  func postProcess(variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration>
  func postProcess(functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration>
  func postProcess(specialDeclaration: SpecialDeclaration, passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration>
  func postProcess(attribute: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute>
  func postProcess(parameter: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter>
  func postProcess(typeAnnotation: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation>
  func postProcess(identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier>
  func postProcess(type: Type, passContext: ASTPassContext) -> ASTPassResult<Type>
  func postProcess(callerCapability: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability>
  func postProcess(expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression>
  func postProcess(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement>
  func postProcess(inoutExpression: InoutExpression, passContext: ASTPassContext) -> ASTPassResult<InoutExpression>
  func postProcess(binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression>
  func postProcess(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall>
  func postProcess(arrayLiteral: ArrayLiteral, passContext: ASTPassContext) -> ASTPassResult<ArrayLiteral>
  func postProcess(rangeExpression: RangeExpression, passContext: ASTPassContext) -> ASTPassResult<RangeExpression>
  func postProcess(dictionaryLiteral: DictionaryLiteral, passContext: ASTPassContext) -> ASTPassResult<DictionaryLiteral>
  func postProcess(literalToken: Token, passContext: ASTPassContext) -> ASTPassResult<Token>
  func postProcess(subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression>
  func postProcess(returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement>
  func postProcess(ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement>
  func postProcess(forStatement: ForStatement, passContext: ASTPassContext) -> ASTPassResult<ForStatement>
}

public struct AnyASTPass: ASTPass {
  var base: ASTPass

  public init(_ base: ASTPass) {
    self.base = base
  }

  public func process(topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule> {
    return base.process(topLevelModule: topLevelModule, passContext: passContext)
  }

  public func process(topLevelDeclaration: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration> {
    return base.process(topLevelDeclaration: topLevelDeclaration, passContext: passContext)
  }

  public func process(contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    return base.process(contractDeclaration: contractDeclaration, passContext: passContext)
  }

  public func process(structDeclaration: StructDeclaration, passContext: ASTPassContext) -> ASTPassResult<StructDeclaration> {
    return base.process(structDeclaration: structDeclaration, passContext: passContext)
  }

  public func process(structMember: StructMember, passContext: ASTPassContext) -> ASTPassResult<StructMember> {
    return base.process(structMember: structMember, passContext: passContext)
  }

  public func process(contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    return base.process(contractBehaviorDeclaration: contractBehaviorDeclaration, passContext: passContext)
  }

  public func process(contractBehaviorMember: ContractBehaviorMember, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorMember> {
    return base.process(contractBehaviorMember: contractBehaviorMember, passContext: passContext)
  }

  public func process(variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    return base.process(variableDeclaration: variableDeclaration, passContext: passContext)
  }

  public func process(functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    return base.process(functionDeclaration: functionDeclaration, passContext: passContext)
  }

  public func process(specialDeclaration: SpecialDeclaration, passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    return base.process(specialDeclaration: specialDeclaration, passContext: passContext)
  }

  public func process(attribute: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute> {
    return base.process(attribute: attribute, passContext: passContext)
  }

  public func process(parameter: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter> {
    return base.process(parameter: parameter, passContext: passContext)
  }

  public func process(typeAnnotation: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation> {
    return base.process(typeAnnotation: typeAnnotation, passContext: passContext)
  }

  public func process(identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier> {
    return base.process(identifier: identifier, passContext: passContext)
  }

  public func process(type: Type, passContext: ASTPassContext) -> ASTPassResult<Type> {
    return base.process(type: type, passContext: passContext)
  }

  public func process(callerCapability: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability> {
    return base.process(callerCapability: callerCapability, passContext: passContext)
  }

  public func process(expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression> {
    return base.process(expression: expression, passContext: passContext)
  }

  public func process(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    return base.process(statement: statement, passContext: passContext)
  }
  
  public func process(inoutExpression: InoutExpression, passContext: ASTPassContext) -> ASTPassResult<InoutExpression> {
    return base.process(inoutExpression: inoutExpression, passContext: passContext)
  }

  public func process(binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    return base.process(binaryExpression: binaryExpression, passContext: passContext)
  }

  public func process(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    return base.process(functionCall: functionCall, passContext: passContext)
  }

  public func process(arrayLiteral: ArrayLiteral, passContext: ASTPassContext) -> ASTPassResult<ArrayLiteral> {
    return base.process(arrayLiteral: arrayLiteral, passContext: passContext)
  }
  
  public func process(rangeExpression: RangeExpression, passContext: ASTPassContext) -> ASTPassResult<RangeExpression> {
    return base.process(rangeExpression: rangeExpression, passContext: passContext)
  }

  public func process(dictionaryLiteral: DictionaryLiteral, passContext: ASTPassContext) -> ASTPassResult<DictionaryLiteral> {
    return base.process(dictionaryLiteral: dictionaryLiteral, passContext: passContext)
  }

  public func process(literalToken: Token, passContext: ASTPassContext) -> ASTPassResult<Token> {
    return base.process(literalToken: literalToken, passContext: passContext)
  }

  public func process(subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    return base.process(subscriptExpression: subscriptExpression, passContext: passContext)
  }


  public func process(returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    return base.process(returnStatement: returnStatement, passContext: passContext)
  }

  public func process(ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    return base.process(ifStatement: ifStatement, passContext: passContext)
  }

  public func process(forStatement: ForStatement, passContext: ASTPassContext) -> ASTPassResult<ForStatement> {
    return base.process(forStatement: forStatement, passContext: passContext)
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

  public func postProcess(contractBehaviorMember: ContractBehaviorMember, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorMember> {
    return base.postProcess(contractBehaviorMember: contractBehaviorMember, passContext: passContext)
  }

  public func postProcess(structDeclaration: StructDeclaration, passContext: ASTPassContext) -> ASTPassResult<StructDeclaration> {
    return base.postProcess(structDeclaration: structDeclaration, passContext: passContext)
  }

  public func postProcess(structMember: StructMember, passContext: ASTPassContext) -> ASTPassResult<StructMember> {
    return base.postProcess(structMember: structMember, passContext: passContext)
  }

  public func postProcess(variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    return base.postProcess(variableDeclaration: variableDeclaration, passContext: passContext)
  }

  public func postProcess(functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    return base.postProcess(functionDeclaration: functionDeclaration, passContext: passContext)
  }

  public func postProcess(specialDeclaration: SpecialDeclaration, passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    return base.postProcess(specialDeclaration: specialDeclaration, passContext: passContext)
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
  
  public func postProcess(inoutExpression: InoutExpression, passContext: ASTPassContext) -> ASTPassResult<InoutExpression> {
    return base.postProcess(inoutExpression: inoutExpression, passContext: passContext)
  }

  public func postProcess(binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    return base.postProcess(binaryExpression: binaryExpression, passContext: passContext)
  }

  public func postProcess(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    return base.postProcess(functionCall: functionCall, passContext: passContext)
  }

  public func postProcess(arrayLiteral: ArrayLiteral, passContext: ASTPassContext) -> ASTPassResult<ArrayLiteral> {
    return base.postProcess(arrayLiteral: arrayLiteral, passContext: passContext)
  }
  
  public func postProcess(rangeExpression: RangeExpression, passContext: ASTPassContext) -> ASTPassResult<RangeExpression> {
    return base.postProcess(rangeExpression: rangeExpression, passContext: passContext)
  }
  
  public func postProcess(dictionaryLiteral: DictionaryLiteral, passContext: ASTPassContext) -> ASTPassResult<DictionaryLiteral> {
    return base.postProcess(dictionaryLiteral: dictionaryLiteral, passContext: passContext)
  }

  public func postProcess(literalToken: Token, passContext: ASTPassContext) -> ASTPassResult<Token> {
    return base.postProcess(literalToken: literalToken, passContext: passContext)
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
  
  public func postProcess(forStatement: ForStatement, passContext: ASTPassContext) -> ASTPassResult<ForStatement> {
    return base.postProcess(forStatement: forStatement, passContext: passContext)
  }
}
