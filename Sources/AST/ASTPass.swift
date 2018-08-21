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

  // MARK: Modules
  func process(_ topLevelModule: TopLevelModule, _ passContext: ASTPassContext) -> ASTPassResult<TopLevelModule>

  // MARK: Top Level Declaration
  func process(_ topLevelDeclaration: TopLevelDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration>
  func process(_ contractDeclaration: ContractDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration>
  func process(_ structDeclaration: StructDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<StructDeclaration>
  func process(_ enumDeclaration: EnumDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<EnumDeclaration>
  func process(_ contractBehaviorDeclaration: ContractBehaviorDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration>

  // MARK: Top Level Members
  func process(_ structMember: StructMember, _ passContext: ASTPassContext) -> ASTPassResult<StructMember>
  func process(_ enumCase: EnumCase, _ passContext: ASTPassContext) -> ASTPassResult<EnumCase>
  func process(_ contractBehaviorMember: ContractBehaviorMember, _ passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorMember>

  // MARK: Statements
  func process(_ statement: Statement, _ passContext: ASTPassContext) -> ASTPassResult<Statement>
  func process(_ returnStatement: ReturnStatement, _ passContext: ASTPassContext) -> ASTPassResult<ReturnStatement>
  func process(_ becomeStatement: BecomeStatement, _ passContext: ASTPassContext) -> ASTPassResult<BecomeStatement>
  func process(_ ifStatement: IfStatement, _ passContext: ASTPassContext) -> ASTPassResult<IfStatement>
  func process(_ forStatement: ForStatement, _ passContext: ASTPassContext) -> ASTPassResult<ForStatement>

  // MARK: Declarations
  func process(_ variableDeclaration: VariableDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration>
  func process(_ functionDeclaration: FunctionDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration>
  func process(_ specialDeclaration: SpecialDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration>

  // MARK: Expression
  func process(_ expression: Expression, _ passContext: ASTPassContext) -> ASTPassResult<Expression>
  func process(_ inoutExpression: InoutExpression, _ passContext: ASTPassContext) -> ASTPassResult<InoutExpression>
  func process(_ binaryExpression: BinaryExpression, _ passContext: ASTPassContext) -> ASTPassResult<BinaryExpression>
  func process(_ functionCall: FunctionCall, _ passContext: ASTPassContext) -> ASTPassResult<FunctionCall>
  func process(_ arrayLiteral: ArrayLiteral, _ passContext: ASTPassContext) -> ASTPassResult<ArrayLiteral>
  func process(_ rangeExpression: RangeExpression, _ passContext: ASTPassContext) -> ASTPassResult<RangeExpression>
  func process(_ dictionaryLiteral: DictionaryLiteral, _ passContext: ASTPassContext) -> ASTPassResult<DictionaryLiteral>
  func process(_ subscriptExpression: SubscriptExpression, _ passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression>

  // MARK: Components
  func process(_ literalToken: Token, _ passContext: ASTPassContext) -> ASTPassResult<Token>
  func process(_ attribute: Attribute, _ passContext: ASTPassContext) -> ASTPassResult<Attribute>
  func process(_ parameter: Parameter, _ passContext: ASTPassContext) -> ASTPassResult<Parameter>
  func process(_ typeAnnotation: TypeAnnotation, _ passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation>
  func process(_ identifier: Identifier, _ passContext: ASTPassContext) -> ASTPassResult<Identifier>
  func process(_ type: Type, _ passContext: ASTPassContext) -> ASTPassResult<Type>
  func process(_ callerCapability: CallerCapability, _ passContext: ASTPassContext) -> ASTPassResult<CallerCapability>
  func process(_ typeState: TypeState, _ passContext: ASTPassContext) -> ASTPassResult<TypeState>

  // MARK: -

  // MARK: Modules
  func postProcess(_ topLevelModule: TopLevelModule, _ passContext: ASTPassContext) -> ASTPassResult<TopLevelModule>

  // MARK: Top Level Declaration
  func postProcess(_ topLevelDeclaration: TopLevelDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration>
  func postProcess(_ contractDeclaration: ContractDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration>
  func postProcess(_ structDeclaration: StructDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<StructDeclaration>
  func postProcess(_ enumDeclaration: EnumDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<EnumDeclaration>
  func postProcess(_ contractBehaviorDeclaration: ContractBehaviorDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration>

  // MARK: Top Level Members
  func postProcess(_ structMember: StructMember, _ passContext: ASTPassContext) -> ASTPassResult<StructMember>
  func postProcess(_ enumCase: EnumCase, _ passContext: ASTPassContext) -> ASTPassResult<EnumCase>
  func postProcess(_ contractBehaviorMember: ContractBehaviorMember, _ passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorMember>

  // MARK: Statements
  func postProcess(_ statement: Statement, _ passContext: ASTPassContext) -> ASTPassResult<Statement>
  func postProcess(_ returnStatement: ReturnStatement, _ passContext: ASTPassContext) -> ASTPassResult<ReturnStatement>
  func postProcess(_ becomeStatement: BecomeStatement, _ passContext: ASTPassContext) -> ASTPassResult<BecomeStatement>
  func postProcess(_ ifStatement: IfStatement, _ passContext: ASTPassContext) -> ASTPassResult<IfStatement>
  func postProcess(_ forStatement: ForStatement, _ passContext: ASTPassContext) -> ASTPassResult<ForStatement>

  // MARK: Declarations
  func postProcess(_ variableDeclaration: VariableDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration>
  func postProcess(_ functionDeclaration: FunctionDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration>
  func postProcess(_ specialDeclaration: SpecialDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration>

  // MARK: Expression
  func postProcess(_ expression: Expression, _ passContext: ASTPassContext) -> ASTPassResult<Expression>
  func postProcess(_ inoutExpression: InoutExpression, _ passContext: ASTPassContext) -> ASTPassResult<InoutExpression>
  func postProcess(_ binaryExpression: BinaryExpression, _ passContext: ASTPassContext) -> ASTPassResult<BinaryExpression>
  func postProcess(_ functionCall: FunctionCall, _ passContext: ASTPassContext) -> ASTPassResult<FunctionCall>
  func postProcess(_ arrayLiteral: ArrayLiteral, _ passContext: ASTPassContext) -> ASTPassResult<ArrayLiteral>
  func postProcess(_ rangeExpression: RangeExpression, _ passContext: ASTPassContext) -> ASTPassResult<RangeExpression>
  func postProcess(_ dictionaryLiteral: DictionaryLiteral, _ passContext: ASTPassContext) -> ASTPassResult<DictionaryLiteral>
  func postProcess(_ subscriptExpression: SubscriptExpression, _ passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression>

  // MARK: Components
  func postProcess(_ literalToken: Token, _ passContext: ASTPassContext) -> ASTPassResult<Token>
  func postProcess(_ attribute: Attribute, _ passContext: ASTPassContext) -> ASTPassResult<Attribute>
  func postProcess(_ parameter: Parameter, _ passContext: ASTPassContext) -> ASTPassResult<Parameter>
  func postProcess(_ typeAnnotation: TypeAnnotation, _ passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation>
  func postProcess(_ identifier: Identifier, _ passContext: ASTPassContext) -> ASTPassResult<Identifier>
  func postProcess(_ type: Type, _ passContext: ASTPassContext) -> ASTPassResult<Type>
  func postProcess(_ callerCapability: CallerCapability, _ passContext: ASTPassContext) -> ASTPassResult<CallerCapability>
  func postProcess(_ typeState: TypeState, _ passContext: ASTPassContext) -> ASTPassResult<TypeState>
}

extension ASTPass {
  // MARK: Modules
  public func process(_ topLevelModule: TopLevelModule, _ passContext: ASTPassContext) -> ASTPassResult<TopLevelModule>  {
    return ASTPassResult(element: topLevelModule, diagnostics: [], passContext: passContext)
  }

  // MARK: Top Level Declaration
  public func process(_ topLevelDeclaration: TopLevelDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration> {
    return ASTPassResult(element: topLevelDeclaration, diagnostics: [], passContext: passContext)
  }
  public func process(_ contractDeclaration: ContractDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    return ASTPassResult(element: contractDeclaration, diagnostics: [], passContext: passContext)
  }
  public func process(_ structDeclaration: StructDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<StructDeclaration> {
    return ASTPassResult(element: structDeclaration, diagnostics: [], passContext: passContext)
  }
  public func process(_ enumDeclaration: EnumDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<EnumDeclaration> {
    return ASTPassResult(element: enumDeclaration, diagnostics: [], passContext: passContext)
  }
  public func process(_ contractBehaviorDeclaration: ContractBehaviorDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    return ASTPassResult(element: contractBehaviorDeclaration, diagnostics: [], passContext: passContext)
  }

  // MARK: Top Level Members
  public func process(_ structMember: StructMember, _ passContext: ASTPassContext) -> ASTPassResult<StructMember> {
    return ASTPassResult(element: structMember, diagnostics: [], passContext: passContext)
  }
  public func process(_ enumCase: EnumCase, _ passContext: ASTPassContext) -> ASTPassResult<EnumCase> {
    return ASTPassResult(element: enumCase, diagnostics: [], passContext: passContext)
  }
  public func process(_ contractBehaviorMember: ContractBehaviorMember, _ passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorMember> {
    return ASTPassResult(element: contractBehaviorMember, diagnostics: [], passContext: passContext)
  }

  // MARK: Statements
  public func process(_ statement: Statement, _ passContext: ASTPassContext) -> ASTPassResult<Statement> {
    return ASTPassResult(element: statement, diagnostics: [], passContext: passContext)
  }
  public func process(_ returnStatement: ReturnStatement, _ passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    return ASTPassResult(element: returnStatement, diagnostics: [], passContext: passContext)
  }
  public func process(_ becomeStatement: BecomeStatement, _ passContext: ASTPassContext) -> ASTPassResult<BecomeStatement> {
    return ASTPassResult(element: becomeStatement, diagnostics: [], passContext: passContext)
  }
  public func process(_ ifStatement: IfStatement, _ passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    return ASTPassResult(element: ifStatement, diagnostics: [], passContext: passContext)
  }
  public func process(_ forStatement: ForStatement, _ passContext: ASTPassContext) -> ASTPassResult<ForStatement> {
    return ASTPassResult(element: forStatement, diagnostics: [], passContext: passContext)
  }

  // MARK: Declarations
  public func process(_ variableDeclaration: VariableDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    return ASTPassResult(element: variableDeclaration, diagnostics: [], passContext: passContext)
  }
  public func process(_ functionDeclaration: FunctionDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }
  public func process(_ specialDeclaration: SpecialDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }

  // MARK: Expression
  public func process(_ expression: Expression, _ passContext: ASTPassContext) -> ASTPassResult<Expression> {
    return ASTPassResult(element: expression, diagnostics: [], passContext: passContext)
  }
  public func process(_ inoutExpression: InoutExpression, _ passContext: ASTPassContext) -> ASTPassResult<InoutExpression> {
    return ASTPassResult(element: inoutExpression, diagnostics: [], passContext: passContext)
  }
  public func process(_ binaryExpression: BinaryExpression, _ passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    return ASTPassResult(element: binaryExpression, diagnostics: [], passContext: passContext)
  }
  public func process(_ functionCall: FunctionCall, _ passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
  }
  public func process(_ rangeExpression: RangeExpression, _ passContext: ASTPassContext) -> ASTPassResult<RangeExpression> {
    return ASTPassResult(element: rangeExpression, diagnostics: [], passContext: passContext)
  }
  public func process(_ subscriptExpression: SubscriptExpression, _ passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    return ASTPassResult(element: subscriptExpression, diagnostics: [], passContext: passContext)
  }
  public func process(_ arrayLiteral: ArrayLiteral, _ passContext: ASTPassContext) -> ASTPassResult<ArrayLiteral> {
    return ASTPassResult(element: arrayLiteral, diagnostics: [], passContext: passContext)
  }
  public func process(_ dictionaryLiteral: DictionaryLiteral, _ passContext: ASTPassContext) -> ASTPassResult<DictionaryLiteral> {
    return ASTPassResult(element: dictionaryLiteral, diagnostics: [], passContext: passContext)
  }

  // MARK: Components
  public func process(_ literalToken: Token, _ passContext: ASTPassContext) -> ASTPassResult<Token> {
    return ASTPassResult(element: literalToken, diagnostics: [], passContext: passContext)
  }
  public func process(_ attribute: Attribute, _ passContext: ASTPassContext) -> ASTPassResult<Attribute> {
    return ASTPassResult(element: attribute, diagnostics: [], passContext: passContext)
  }
  public func process(_ parameter: Parameter, _ passContext: ASTPassContext) -> ASTPassResult<Parameter> {
    return ASTPassResult(element: parameter, diagnostics: [], passContext: passContext)
  }
  public func process(_ typeAnnotation: TypeAnnotation, _ passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation> {
    return ASTPassResult(element: typeAnnotation, diagnostics: [], passContext: passContext)
  }
  public func process(_ identifier: Identifier, _ passContext: ASTPassContext) -> ASTPassResult<Identifier> {
    return ASTPassResult(element: identifier, diagnostics: [], passContext: passContext)
  }
  public func process(_ type: Type, _ passContext: ASTPassContext) -> ASTPassResult<Type> {
    return ASTPassResult(element: type, diagnostics: [], passContext: passContext)
  }
  public func process(_ callerCapability: CallerCapability, _ passContext: ASTPassContext) -> ASTPassResult<CallerCapability> {
    return ASTPassResult(element: callerCapability, diagnostics: [], passContext: passContext)
  }
  public func process(_ typeState: TypeState, _ passContext: ASTPassContext) -> ASTPassResult<TypeState> {
    return ASTPassResult(element: typeState, diagnostics: [], passContext: passContext)
  }

  // MARK: -

  // MARK: Modules
  public func postProcess(_ topLevelModule: TopLevelModule, _ passContext: ASTPassContext) -> ASTPassResult<TopLevelModule> {
    return ASTPassResult(element: topLevelModule, diagnostics: [], passContext: passContext)
  }

  // MARK: Top Level Declaration
  public func postProcess(_ topLevelDeclaration: TopLevelDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration> {
    return ASTPassResult(element: topLevelDeclaration, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ contractDeclaration: ContractDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    return ASTPassResult(element: contractDeclaration, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ structDeclaration: StructDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<StructDeclaration> {
    return ASTPassResult(element: structDeclaration, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ enumDeclaration: EnumDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<EnumDeclaration> {
    return ASTPassResult(element: enumDeclaration, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ contractBehaviorDeclaration: ContractBehaviorDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    return ASTPassResult(element: contractBehaviorDeclaration, diagnostics: [], passContext: passContext)
  }

  // MARK: Top Level Members
  public func postProcess(_ structMember: StructMember, _ passContext: ASTPassContext) -> ASTPassResult<StructMember> {
    return ASTPassResult(element: structMember, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ enumCase: EnumCase, _ passContext: ASTPassContext) -> ASTPassResult<EnumCase> {
    return ASTPassResult(element: enumCase, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ contractBehaviorMember: ContractBehaviorMember, _ passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorMember> {
    return ASTPassResult(element: contractBehaviorMember, diagnostics: [], passContext: passContext)
  }

  // MARK: Statements
  public func postProcess(_ statement: Statement, _ passContext: ASTPassContext) -> ASTPassResult<Statement> {
    return ASTPassResult(element: statement, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ returnStatement: ReturnStatement, _ passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    return ASTPassResult(element: returnStatement, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ becomeStatement: BecomeStatement, _ passContext: ASTPassContext) -> ASTPassResult<BecomeStatement> {
    return ASTPassResult(element: becomeStatement, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ ifStatement: IfStatement, _ passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    return ASTPassResult(element: ifStatement, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ forStatement: ForStatement, _ passContext: ASTPassContext) -> ASTPassResult<ForStatement> {
    return ASTPassResult(element: forStatement, diagnostics: [], passContext: passContext)
  }

  // MARK: Declarations
  public func postProcess(_ variableDeclaration: VariableDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    return ASTPassResult(element: variableDeclaration, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ functionDeclaration: FunctionDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ specialDeclaration: SpecialDeclaration, _ passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }

  // MARK: Expression
  public func postProcess(_ expression: Expression, _ passContext: ASTPassContext) -> ASTPassResult<Expression> {
    return ASTPassResult(element: expression, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ inoutExpression: InoutExpression, _ passContext: ASTPassContext) -> ASTPassResult<InoutExpression> {
    return ASTPassResult(element: inoutExpression, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ binaryExpression: BinaryExpression, _ passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    return ASTPassResult(element: binaryExpression, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ functionCall: FunctionCall, _ passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ rangeExpression: RangeExpression, _ passContext: ASTPassContext) -> ASTPassResult<RangeExpression> {
    return ASTPassResult(element: rangeExpression, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ subscriptExpression: SubscriptExpression, _ passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    return ASTPassResult(element: subscriptExpression, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ arrayLiteral: ArrayLiteral, _ passContext: ASTPassContext) -> ASTPassResult<ArrayLiteral> {
    return ASTPassResult(element: arrayLiteral, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ dictionaryLiteral: DictionaryLiteral, _ passContext: ASTPassContext) -> ASTPassResult<DictionaryLiteral> {
    return ASTPassResult(element: dictionaryLiteral, diagnostics: [], passContext: passContext)
  }

  // MARK: Components
  public func postProcess(_ literalToken: Token, _ passContext: ASTPassContext) -> ASTPassResult<Token> {
    return ASTPassResult(element: literalToken, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ attribute: Attribute, _ passContext: ASTPassContext) -> ASTPassResult<Attribute> {
    return ASTPassResult(element: attribute, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ parameter: Parameter, _ passContext: ASTPassContext) -> ASTPassResult<Parameter> {
    return ASTPassResult(element: parameter, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ typeAnnotation: TypeAnnotation, _ passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation> {
    return ASTPassResult(element: typeAnnotation, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ identifier: Identifier, _ passContext: ASTPassContext) -> ASTPassResult<Identifier> {
    return ASTPassResult(element: identifier, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ type: Type, _ passContext: ASTPassContext) -> ASTPassResult<Type> {
    return ASTPassResult(element: type, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ callerCapability: CallerCapability, _ passContext: ASTPassContext) -> ASTPassResult<CallerCapability> {
    return ASTPassResult(element: callerCapability, diagnostics: [], passContext: passContext)
  }
  public func postProcess(_ typeState: TypeState, _ passContext: ASTPassContext) -> ASTPassResult<TypeState> {
    return ASTPassResult(element: typeState, diagnostics: [], passContext: passContext)
  }
}
