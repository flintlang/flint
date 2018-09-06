//
//  ASTPass.swift
//  AST
//
//  Created by Franklin Schrans on 1/11/18.
//
import Diagnostic
import Lexer

/// A pass over an AST.
///
/// The class `ASTVisitor` is used to visit an AST using a given `ASTPass`. The appropriate `process` function will be
/// called when visiting a node, and `postProcess` will be called after visiting the children of that node.
public protocol ASTPass {

  // MARK: Modules
  func process(topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule>

  // MARK: Top Level Declarations
  func process(topLevelDeclaration: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration>
  func process(contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration>
  func process(structDeclaration: StructDeclaration, passContext: ASTPassContext) -> ASTPassResult<StructDeclaration>
  func process(enumDeclaration: EnumDeclaration, passContext: ASTPassContext) -> ASTPassResult<EnumDeclaration>
  func process(traitDeclaration: TraitDeclaration, passContext: ASTPassContext) -> ASTPassResult<TraitDeclaration>
  func process(contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration>

  // MARK: Top Level Members
  func process(contractMember: ContractMember, passContext: ASTPassContext) -> ASTPassResult<ContractMember>
  func process(structMember: StructMember, passContext: ASTPassContext) -> ASTPassResult<StructMember>
  func process(enumCase: EnumMember, passContext: ASTPassContext) -> ASTPassResult<EnumMember>
  func process(traitMember: TraitMember, passContext: ASTPassContext) -> ASTPassResult<TraitMember>
  func process(contractBehaviorMember: ContractBehaviorMember, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorMember>

  // MARK: Statements
  func process(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement>
  func process(returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement>
  func process(becomeStatement: BecomeStatement, passContext: ASTPassContext) -> ASTPassResult<BecomeStatement>
  func process(emitStatement: EmitStatement, passContext: ASTPassContext) -> ASTPassResult<EmitStatement>
  func process(ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement>
  func process(forStatement: ForStatement, passContext: ASTPassContext) -> ASTPassResult<ForStatement>

  // MARK: Declarations
  func process(variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration>
  func process(functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration>
  func process(functionSignatureDeclaration: FunctionSignatureDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionSignatureDeclaration>
  func process(specialDeclaration: SpecialDeclaration, passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration>
  func process(eventDeclaration: EventDeclaration, passContext: ASTPassContext) -> ASTPassResult<EventDeclaration>

  // MARK: Expression
  func process(expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression>
  func process(inoutExpression: InoutExpression, passContext: ASTPassContext) -> ASTPassResult<InoutExpression>
  func process(binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression>
  func process(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall>
  func process(arrayLiteral: ArrayLiteral, passContext: ASTPassContext) -> ASTPassResult<ArrayLiteral>
  func process(rangeExpression: RangeExpression, passContext: ASTPassContext) -> ASTPassResult<RangeExpression>
  func process(dictionaryLiteral: AST.DictionaryLiteral, passContext: ASTPassContext) -> ASTPassResult<AST.DictionaryLiteral>
  func process(subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression>
  func process(attemptExpression: AttemptExpression, passContext: ASTPassContext) -> ASTPassResult<AttemptExpression>

  // MARK: Components
  func process(literalToken: Token, passContext: ASTPassContext) -> ASTPassResult<Token>
  func process(attribute: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute>
  func process(parameter: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter>
  func process(typeAnnotation: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation>
  func process(identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier>
  func process(type: Type, passContext: ASTPassContext) -> ASTPassResult<Type>
  func process(callerCapability: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability>
  func process(typeState: TypeState, passContext: ASTPassContext) -> ASTPassResult<TypeState>
  func process(functionArgument: FunctionArgument, passContext: ASTPassContext) -> ASTPassResult<FunctionArgument>

  // MARK: -

  // MARK: Modules
  func postProcess(topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule>

  // MARK: Top Level Declaration
  func postProcess(topLevelDeclaration: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration>
  func postProcess(contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration>
  func postProcess(structDeclaration: StructDeclaration, passContext: ASTPassContext) -> ASTPassResult<StructDeclaration>
  func postProcess(enumDeclaration: EnumDeclaration, passContext: ASTPassContext) -> ASTPassResult<EnumDeclaration>
  func postProcess(traitDeclaration: TraitDeclaration, passContext: ASTPassContext) -> ASTPassResult<TraitDeclaration>
  func postProcess(contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration>

  // MARK: Top Level Members
  func postProcess(contractMember: ContractMember, passContext: ASTPassContext) -> ASTPassResult<ContractMember>
  func postProcess(structMember: StructMember, passContext: ASTPassContext) -> ASTPassResult<StructMember>
  func postProcess(enumCase: EnumMember, passContext: ASTPassContext) -> ASTPassResult<EnumMember>
  func postProcess(traitMember: TraitMember, passContext: ASTPassContext) -> ASTPassResult<TraitMember>
  func postProcess(contractBehaviorMember: ContractBehaviorMember, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorMember>

  // MARK: Statements
  func postProcess(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement>
  func postProcess(returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement>
  func postProcess(becomeStatement: BecomeStatement, passContext: ASTPassContext) -> ASTPassResult<BecomeStatement>
  func postProcess(emitStatement: EmitStatement, passContext: ASTPassContext) -> ASTPassResult<EmitStatement>
  func postProcess(ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement>
  func postProcess(forStatement: ForStatement, passContext: ASTPassContext) -> ASTPassResult<ForStatement>

  // MARK: Declarations
  func postProcess(variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration>
  func postProcess(functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration>
  func postProcess(functionSignatureDeclaration: FunctionSignatureDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionSignatureDeclaration>
  func postProcess(specialDeclaration: SpecialDeclaration, passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration>
  func postProcess(eventDeclaration: EventDeclaration, passContext: ASTPassContext) -> ASTPassResult<EventDeclaration>

  // MARK: Expression
  func postProcess(expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression>
  func postProcess(inoutExpression: InoutExpression, passContext: ASTPassContext) -> ASTPassResult<InoutExpression>
  func postProcess(binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression>
  func postProcess(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall>
  func postProcess(arrayLiteral: ArrayLiteral, passContext: ASTPassContext) -> ASTPassResult<ArrayLiteral>
  func postProcess(rangeExpression: RangeExpression, passContext: ASTPassContext) -> ASTPassResult<RangeExpression>
  func postProcess(dictionaryLiteral: DictionaryLiteral, passContext: ASTPassContext) -> ASTPassResult<DictionaryLiteral>
  func postProcess(subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression>
  func postProcess(attemptExpression: AttemptExpression, passContext: ASTPassContext) -> ASTPassResult<AttemptExpression>

  // MARK: Components
  func postProcess(literalToken: Token, passContext: ASTPassContext) -> ASTPassResult<Token>
  func postProcess(attribute: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute>
  func postProcess(parameter: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter>
  func postProcess(typeAnnotation: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation>
  func postProcess(identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier>
  func postProcess(type: Type, passContext: ASTPassContext) -> ASTPassResult<Type>
  func postProcess(callerCapability: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability>
  func postProcess(typeState: TypeState, passContext: ASTPassContext) -> ASTPassResult<TypeState>
  func postProcess(functionArgument: FunctionArgument, passContext: ASTPassContext) -> ASTPassResult<FunctionArgument>

}

extension ASTPass {
  // MARK: Modules
  public func process(topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule>  {
    return ASTPassResult(element: topLevelModule, diagnostics: [], passContext: passContext)
  }

  // MARK: Top Level Declaration
  public func process(topLevelDeclaration: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration> {
    return ASTPassResult(element: topLevelDeclaration, diagnostics: [], passContext: passContext)
  }
  public func process(contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    return ASTPassResult(element: contractDeclaration, diagnostics: [], passContext: passContext)
  }
  public func process(structDeclaration: StructDeclaration, passContext: ASTPassContext) -> ASTPassResult<StructDeclaration> {
    return ASTPassResult(element: structDeclaration, diagnostics: [], passContext: passContext)
  }
  public func process(enumDeclaration: EnumDeclaration, passContext: ASTPassContext) -> ASTPassResult<EnumDeclaration> {
    return ASTPassResult(element: enumDeclaration, diagnostics: [], passContext: passContext)
  }
  public func process(traitDeclaration: TraitDeclaration, passContext: ASTPassContext) -> ASTPassResult<TraitDeclaration> {
    return ASTPassResult(element: traitDeclaration, diagnostics: [], passContext: passContext)
  }
  public func process(contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    return ASTPassResult(element: contractBehaviorDeclaration, diagnostics: [], passContext: passContext)
  }

  // MARK: Top Level Members
  public func process(contractMember: ContractMember, passContext: ASTPassContext) -> ASTPassResult<ContractMember> {
    return ASTPassResult(element: contractMember, diagnostics: [], passContext: passContext)
  }
  public func process(structMember: StructMember, passContext: ASTPassContext) -> ASTPassResult<StructMember> {
    return ASTPassResult(element: structMember, diagnostics: [], passContext: passContext)
  }
  public func process(enumCase: EnumMember, passContext: ASTPassContext) -> ASTPassResult<EnumMember> {
    return ASTPassResult(element: enumCase, diagnostics: [], passContext: passContext)
  }
  public func process(traitMember: TraitMember, passContext: ASTPassContext) -> ASTPassResult<TraitMember> {
    return ASTPassResult(element: traitMember, diagnostics: [], passContext: passContext)
  }
  public func process(contractBehaviorMember: ContractBehaviorMember, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorMember> {
    return ASTPassResult(element: contractBehaviorMember, diagnostics: [], passContext: passContext)
  }

  // MARK: Statements
  public func process(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    return ASTPassResult(element: statement, diagnostics: [], passContext: passContext)
  }
  public func process(returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    return ASTPassResult(element: returnStatement, diagnostics: [], passContext: passContext)
  }
  public func process(becomeStatement: BecomeStatement, passContext: ASTPassContext) -> ASTPassResult<BecomeStatement> {
    return ASTPassResult(element: becomeStatement, diagnostics: [], passContext: passContext)
  }
  public func process(emitStatement: EmitStatement, passContext: ASTPassContext) -> ASTPassResult<EmitStatement> {
    return ASTPassResult(element: emitStatement, diagnostics: [], passContext: passContext)
  }
  public func process(ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    return ASTPassResult(element: ifStatement, diagnostics: [], passContext: passContext)
  }
  public func process(forStatement: ForStatement, passContext: ASTPassContext) -> ASTPassResult<ForStatement> {
    return ASTPassResult(element: forStatement, diagnostics: [], passContext: passContext)
  }

  // MARK: Declarations
  public func process(variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    return ASTPassResult(element: variableDeclaration, diagnostics: [], passContext: passContext)
  }
  public func process(functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }
  public func process(functionSignatureDeclaration: FunctionSignatureDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionSignatureDeclaration> {
    return ASTPassResult(element: functionSignatureDeclaration, diagnostics: [], passContext: passContext)
  }
  public func process(specialDeclaration: SpecialDeclaration, passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }
  public func process(eventDeclaration: EventDeclaration, passContext: ASTPassContext) -> ASTPassResult<EventDeclaration> {
    return ASTPassResult(element: eventDeclaration, diagnostics: [], passContext: passContext)
  }

  // MARK: Expression
  public func process(expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression> {
    return ASTPassResult(element: expression, diagnostics: [], passContext: passContext)
  }
  public func process(inoutExpression: InoutExpression, passContext: ASTPassContext) -> ASTPassResult<InoutExpression> {
    return ASTPassResult(element: inoutExpression, diagnostics: [], passContext: passContext)
  }
  public func process(binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    return ASTPassResult(element: binaryExpression, diagnostics: [], passContext: passContext)
  }
  public func process(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
  }
  public func process(rangeExpression: RangeExpression, passContext: ASTPassContext) -> ASTPassResult<RangeExpression> {
    return ASTPassResult(element: rangeExpression, diagnostics: [], passContext: passContext)
  }
  public func process(subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    return ASTPassResult(element: subscriptExpression, diagnostics: [], passContext: passContext)
  }
  public func process(attemptExpression: AttemptExpression, passContext: ASTPassContext) -> ASTPassResult<AttemptExpression> {
    return ASTPassResult(element: attemptExpression, diagnostics: [], passContext: passContext)
  }
  public func process(arrayLiteral: ArrayLiteral, passContext: ASTPassContext) -> ASTPassResult<ArrayLiteral> {
    return ASTPassResult(element: arrayLiteral, diagnostics: [], passContext: passContext)
  }
  public func process(dictionaryLiteral: DictionaryLiteral, passContext: ASTPassContext) -> ASTPassResult<DictionaryLiteral> {
    return ASTPassResult(element: dictionaryLiteral, diagnostics: [], passContext: passContext)
  }

  // MARK: Components
  public func process(literalToken: Token, passContext: ASTPassContext) -> ASTPassResult<Token> {
    return ASTPassResult(element: literalToken, diagnostics: [], passContext: passContext)
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
    return ASTPassResult(element: identifier, diagnostics: [], passContext: passContext)
  }
  public func process(type: Type, passContext: ASTPassContext) -> ASTPassResult<Type> {
    return ASTPassResult(element: type, diagnostics: [], passContext: passContext)
  }
  public func process(callerCapability: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability> {
    return ASTPassResult(element: callerCapability, diagnostics: [], passContext: passContext)
  }
  public func process(typeState: TypeState, passContext: ASTPassContext) -> ASTPassResult<TypeState> {
    return ASTPassResult(element: typeState, diagnostics: [], passContext: passContext)
  }
  public func process(functionArgument: FunctionArgument, passContext: ASTPassContext) -> ASTPassResult<FunctionArgument> {
    return ASTPassResult(element: functionArgument, diagnostics: [], passContext: passContext)
  }

  // MARK: -

  // MARK: Modules
  public func postProcess(topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule> {
    return ASTPassResult(element: topLevelModule, diagnostics: [], passContext: passContext)
  }

  // MARK: Top Level Declaration
  public func postProcess(topLevelDeclaration: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration> {
    return ASTPassResult(element: topLevelDeclaration, diagnostics: [], passContext: passContext)
  }
  public func postProcess(contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    return ASTPassResult(element: contractDeclaration, diagnostics: [], passContext: passContext)
  }
  public func postProcess(structDeclaration: StructDeclaration, passContext: ASTPassContext) -> ASTPassResult<StructDeclaration> {
    return ASTPassResult(element: structDeclaration, diagnostics: [], passContext: passContext)
  }
  public func postProcess(enumDeclaration: EnumDeclaration, passContext: ASTPassContext) -> ASTPassResult<EnumDeclaration> {
    return ASTPassResult(element: enumDeclaration, diagnostics: [], passContext: passContext)
  }
  public func postProcess(traitDeclaration: TraitDeclaration, passContext: ASTPassContext) -> ASTPassResult<TraitDeclaration> {
    return ASTPassResult(element: traitDeclaration, diagnostics: [], passContext: passContext)
  }
  public func postProcess(contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    return ASTPassResult(element: contractBehaviorDeclaration, diagnostics: [], passContext: passContext)
  }

  // MARK: Top Level Members
  public func postProcess(contractMember: ContractMember, passContext: ASTPassContext) -> ASTPassResult<ContractMember> {
    return ASTPassResult(element: contractMember, diagnostics: [], passContext: passContext)
  }
  public func postProcess(structMember: StructMember, passContext: ASTPassContext) -> ASTPassResult<StructMember> {
    return ASTPassResult(element: structMember, diagnostics: [], passContext: passContext)
  }
  public func postProcess(enumCase: EnumMember, passContext: ASTPassContext) -> ASTPassResult<EnumMember> {
    return ASTPassResult(element: enumCase, diagnostics: [], passContext: passContext)
  }
  public func postProcess(traitMember: TraitMember, passContext: ASTPassContext) -> ASTPassResult<TraitMember> {
    return ASTPassResult(element: traitMember, diagnostics: [], passContext: passContext)
  }
  public func postProcess(contractBehaviorMember: ContractBehaviorMember, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorMember> {
    return ASTPassResult(element: contractBehaviorMember, diagnostics: [], passContext: passContext)
  }

  // MARK: Statements
  public func postProcess(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    return ASTPassResult(element: statement, diagnostics: [], passContext: passContext)
  }
  public func postProcess(returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    return ASTPassResult(element: returnStatement, diagnostics: [], passContext: passContext)
  }
  public func postProcess(becomeStatement: BecomeStatement, passContext: ASTPassContext) -> ASTPassResult<BecomeStatement> {
    return ASTPassResult(element: becomeStatement, diagnostics: [], passContext: passContext)
  }
  public func postProcess(emitStatement: EmitStatement, passContext: ASTPassContext) -> ASTPassResult<EmitStatement> {
    return ASTPassResult(element: emitStatement, diagnostics: [], passContext: passContext)
  }
  public func postProcess(ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    return ASTPassResult(element: ifStatement, diagnostics: [], passContext: passContext)
  }
  public func postProcess(forStatement: ForStatement, passContext: ASTPassContext) -> ASTPassResult<ForStatement> {
    return ASTPassResult(element: forStatement, diagnostics: [], passContext: passContext)
  }

  // MARK: Declarations
  public func postProcess(variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    return ASTPassResult(element: variableDeclaration, diagnostics: [], passContext: passContext)
  }
  public func postProcess(functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }
  public func postProcess(functionSignatureDeclaration: FunctionSignatureDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionSignatureDeclaration> {
    return ASTPassResult(element: functionSignatureDeclaration, diagnostics: [], passContext: passContext)
  }
  public func postProcess(specialDeclaration: SpecialDeclaration, passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }
  public func postProcess(eventDeclaration: EventDeclaration, passContext: ASTPassContext) -> ASTPassResult<EventDeclaration> {
    return ASTPassResult(element: eventDeclaration, diagnostics: [], passContext: passContext)
  }

  // MARK: Expression
  public func postProcess(expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression> {
    return ASTPassResult(element: expression, diagnostics: [], passContext: passContext)
  }
  public func postProcess(inoutExpression: InoutExpression, passContext: ASTPassContext) -> ASTPassResult<InoutExpression> {
    return ASTPassResult(element: inoutExpression, diagnostics: [], passContext: passContext)
  }
  public func postProcess(binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    return ASTPassResult(element: binaryExpression, diagnostics: [], passContext: passContext)
  }
  public func postProcess(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
  }
  public func postProcess(rangeExpression: RangeExpression, passContext: ASTPassContext) -> ASTPassResult<RangeExpression> {
    return ASTPassResult(element: rangeExpression, diagnostics: [], passContext: passContext)
  }
  public func postProcess(subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    return ASTPassResult(element: subscriptExpression, diagnostics: [], passContext: passContext)
  }
  public func postProcess(attemptExpression: AttemptExpression, passContext: ASTPassContext) -> ASTPassResult<AttemptExpression> {
    return ASTPassResult(element: attemptExpression, diagnostics: [], passContext: passContext)
  }
  public func postProcess(arrayLiteral: ArrayLiteral, passContext: ASTPassContext) -> ASTPassResult<ArrayLiteral> {
    return ASTPassResult(element: arrayLiteral, diagnostics: [], passContext: passContext)
  }
  public func postProcess(dictionaryLiteral: DictionaryLiteral, passContext: ASTPassContext) -> ASTPassResult<DictionaryLiteral> {
    return ASTPassResult(element: dictionaryLiteral, diagnostics: [], passContext: passContext)
  }

  // MARK: Components
  public func postProcess(literalToken: Token, passContext: ASTPassContext) -> ASTPassResult<Token> {
    return ASTPassResult(element: literalToken, diagnostics: [], passContext: passContext)
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
  public func postProcess(typeState: TypeState, passContext: ASTPassContext) -> ASTPassResult<TypeState> {
    return ASTPassResult(element: typeState, diagnostics: [], passContext: passContext)
  }
  public func postProcess(functionArgument: FunctionArgument, passContext: ASTPassContext) -> ASTPassResult<FunctionArgument> {
    return ASTPassResult(element: functionArgument, diagnostics: [], passContext: passContext)
  }
}
