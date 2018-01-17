//
//  ASTPass.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 1/11/18.
//

public protocol ASTPass {
  func process(element: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule>
  func process(element: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration>
  func process(element: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration>
  func process(element: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration>
  func process(element: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration>
  func process(element: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration>
  func process(element: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute>
  func process(element: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter>
  func process(element: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation>
  func process(element: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier>
  func process(element: Type, passContext: ASTPassContext) -> ASTPassResult<Type>
  func process(element: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability>
  func process(element: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression>
  func process(element: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement>
  func process(element: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression>
  func process(element: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall>
  func process(element: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression>
  func process(element: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement>
  func process(element: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement>
}

public struct AnyASTPass: ASTPass {
  var base: ASTPass

  public init(_ base: ASTPass) {
    self.base = base
  }

  public func process(element: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule> {
    return base.process(element: element, passContext: passContext)
  }

  public func process(element: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration> {
    return base.process(element: element, passContext: passContext)
  }

  public func process(element: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    return base.process(element: element, passContext: passContext)
  }

  public func process(element: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    return base.process(element: element, passContext: passContext)
  }

  public func process(element: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    return base.process(element: element, passContext: passContext)
  }

  public func process(element: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    return base.process(element: element, passContext: passContext)
  }

  public func process(element: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute> {
    return base.process(element: element, passContext: passContext)
  }

  public func process(element: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter> {
    return base.process(element: element, passContext: passContext)
  }

  public func process(element: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation> {
    return base.process(element: element, passContext: passContext)
  }

  public func process(element: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier> {
    return base.process(element: element, passContext: passContext)
  }

  public func process(element: Type, passContext: ASTPassContext) -> ASTPassResult<Type> {
    return base.process(element: element, passContext: passContext)
  }

  public func process(element: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability> {
    return base.process(element: element, passContext: passContext)
  }

  public func process(element: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression> {
    return base.process(element: element, passContext: passContext)
  }

  public func process(element: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    return base.process(element: element, passContext: passContext)
  }

  public func process(element: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    return base.process(element: element, passContext: passContext)
  }

  public func process(element: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    return base.process(element: element, passContext: passContext)
  }

  public func process(element: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    return base.process(element: element, passContext: passContext)
  }


  public func process(element: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    return base.process(element: element, passContext: passContext)
  }

  public func process(element: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    return base.process(element: element, passContext: passContext)
  }
}
