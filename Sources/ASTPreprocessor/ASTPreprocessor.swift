//
//  ASTPreprocessor.swift
//  ASTPreprocessor
//
//  Created by Nik Vangerow on 11/22/18.
//

import AST

/// Performs left-rotations on binary expressions that should be left-associative
public struct ASTPreprocessor: ASTPass {

  public init() {}

  // Make binary expressions involving the dot (.) operator left-associative.
  // Binary expressions are parsed with the wrong associativity. Due to the recursive descent parsing,
  // Expressions associate to the right: a.(b.c). This is wrong. We want them to associate to the right: (a.b).c.
  public func process(binaryExpression: BinaryExpression,
                      passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    guard binaryExpression.opToken == .dot else {
      return ASTPassResult(element: binaryExpression, diagnostics: [], passContext: passContext)
    }

    // Find the pivot.
    // The pivot MUST be a direct right hand descendant of this expression to be valid.
    // Otherwise we have reached a leaf node.
    guard case .binaryExpression(let pivot) = binaryExpression.rhs, pivot.opToken == .dot else {
      return ASTPassResult(element: binaryExpression, diagnostics: [], passContext: passContext)
    }

    let transformedLHS = BinaryExpression(lhs: binaryExpression.lhs, op: binaryExpression.op, rhs: pivot.lhs)
    let transformedRHS = pivot.rhs

    let newBinaryExpression = BinaryExpression(lhs: .binaryExpression(transformedLHS),
                                               op: pivot.op,
                                               rhs: transformedRHS)

    return ASTPassResult(element: newBinaryExpression, diagnostics: [], passContext: passContext)
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
