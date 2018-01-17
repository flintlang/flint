//
//  TypeChecker.swift
//  flintc
//
//  Created by Franklin Schrans on 1/11/18.
//

import AST

public struct TypeChecker: ASTPass {
  public init() {}
  
  public func process(element: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule> {
    let visitor = TypeCheckerVisitor(context: passContext.context!)
    visitor.visit(element)
    return ASTPassResult(element: element, diagnostics: visitor.diagnostics, passContext: passContext)
  }

  public func process(element: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: Type, passContext: ASTPassContext) -> ASTPassResult<Type> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }

  public func process(element: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    return ASTPassResult(element: element, diagnostics: [], passContext: passContext)
  }
}
