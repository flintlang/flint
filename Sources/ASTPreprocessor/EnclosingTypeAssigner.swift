//
//  EnclosingTypeAssigner.swift
//  ASTPreprocessor
//
//  Created by Nik on 23/11/2018.
//

import AST
import Diagnostic

/// The Enclosing Type Assignment pass for the AST.
/// Sets the `enclosingType` property of expressions to enable type resolution later on.
/// This is the 'parent' type for variable access (e.g. the enclosing type of x is the type of b in the expression b.x)
public struct EnclosingTypeAssigner: ASTPass {

  public init() {}

  public func process(variableDeclaration: VariableDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    var passContext = passContext
    if passContext.inFunctionOrInitializer {
        // We're in a function. Record the local variable declaration.
        passContext.scopeContext?.localVariables += [variableDeclaration]
    }
    return ASTPassResult(element: variableDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(binaryExpression: BinaryExpression,
                          passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    var binaryExpression = binaryExpression
    let environment = passContext.environment!

    if case .dot = binaryExpression.opToken {
      // The identifier explicitly refers to a state property, such as in `self.foo`.
      // We set its enclosing type to the type it is declared in.
      let enclosingType = passContext.enclosingTypeIdentifier!
      let lhsType = environment.type(of: binaryExpression.lhs,
                                     enclosingType: enclosingType.name,
                                     scopeContext: passContext.scopeContext!)
      if case .identifier(let enumIdentifier) = binaryExpression.lhs,
        environment.isEnumDeclared(enumIdentifier.name) {
        binaryExpression.rhs = binaryExpression.rhs.assigningEnclosingType(type: enumIdentifier.name)
      } else if lhsType == .selfType {
        if let traitDeclarationContext = passContext.traitDeclarationContext {
          binaryExpression.rhs =
            binaryExpression.rhs.assigningEnclosingType(type: traitDeclarationContext.traitIdentifier.name)
        }
      } else {
        binaryExpression.rhs = binaryExpression.rhs.assigningEnclosingType(type: lhsType.name)
      }
    }

    return ASTPassResult(element: binaryExpression, diagnostics: [], passContext: passContext)
  }

  public func postProcess(forStatement: ForStatement, passContext: ASTPassContext) -> ASTPassResult<ForStatement> {
    var forStatement = forStatement
    // The current ASTVisitor assumes that we walk through the entire tree and set up a scope context that includes
    // all VariableDeclarations, which is stored in forBodyScopeContext as part of the visit to ForStatement.
    // Since this pass DOES NOT do this, we end up passing forward an empty ScopeContext
    // which means that loop variables are not visible. Adding any pass at all before one that visits the
    // VariableDeclarations requires the forBodyScopeContext to be set to nil.
    // This is a flaw in the implementation of visit(_:passContext) for ForStatement.
    forStatement.forBodyScopeContext = nil
    return ASTPassResult(element: forStatement, diagnostics: [], passContext: passContext)
  }

  public func postProcess(ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    var ifStatement = ifStatement
    // The current ASTVisitor assumes that we walk through the entire tree and set up a scope context that includes
    // all VariableDeclarations, which is stored in ifBodyScopeContext & elseBodyScopeContext as part of the visit to
    // IfStatement.
    // Since this pass DOES NOT do this, we end up passing forward an empty ScopeContext
    // which means that if and else body variables are not visible. Adding any pass at all before one that visits the
    // VariableDeclarations requires the ifBodyScopeContext & elseBodyScopeContext to be set to nil.
    // This is a flaw in the implementation of visit(_:passContext) for IfStatement.
    ifStatement.ifBodyScopeContext = nil
    ifStatement.elseBodyScopeContext = nil
    return ASTPassResult(element: ifStatement, diagnostics: [], passContext: passContext)
  }

}
