//
//  TypeChecker.swift
//  flintc
//
//  Created by Franklin Schrans on 1/11/18.
//

import AST

public struct TypeChecker: ASTPass {
  public init() {}
  
  public func run(for ast: TopLevelModule, in context: Context) -> ASTPassResult {
    let visitor = TypeCheckerVisitor(context: context)
    visitor.visit(ast)
    return .init(diagnostics: visitor.diagnostics, context: visitor.context)
  }
}
