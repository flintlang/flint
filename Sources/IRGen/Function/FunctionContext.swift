//
//  Context.swift
//  IRGen
//
//  Created by Franklin Schrans on 27/04/2018.
//

import YUL
import AST


/// Context used when generating code the body of a function.
class FunctionContext {
  /// Environment information, such as typing of variables, for the source program.
  var environment: Environment

  /// Set of local variables defined in the scope of the function, including caller bindings.
  var scopeContext: ScopeContext

  /// The type in which the function is declared.
  var enclosingTypeName: String

  /// Whether the function is declared in a struct.
  var isInStructFunction: Bool

  var doCatchStatementStack: [DoCatchStatement]

  var currentBlock: YUL.Block

  init(environment: Environment,
       scopeContext: ScopeContext,
       enclosingTypeName: String,
       isInStructFunction: Bool,
       doCatchStatementStack: [DoCatchStatement] = []) {
    self.environment = environment
    self.scopeContext = scopeContext
    self.enclosingTypeName = enclosingTypeName
    self.isInStructFunction = isInStructFunction
    self.doCatchStatementStack = doCatchStatementStack

    self.currentBlock = YUL.Block([])
  }

  func emit(_ statement: YUL.Statement) {
    self.currentBlock.statements.append(statement)
  }

  func withNewBlock(_ inner: () -> ()) -> YUL.Block {
    let oldBlock = self.currentBlock
    self.currentBlock = YUL.Block([])
    inner()
    let retBlock = self.currentBlock
    self.currentBlock = oldBlock
    return retBlock
  }

  func push(doCatch stmt: DoCatchStatement) {
    doCatchStatementStack.append(stmt)
  }

  @discardableResult
  func pop() -> DoCatchStatement? {
    return doCatchStatementStack.popLast()
  }

  var top: DoCatchStatement? {
    return doCatchStatementStack.last
  }

}
