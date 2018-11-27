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

  var blockStack: [YUL.Block]
  private var counter: Int

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

    self.blockStack = [YUL.Block([])]
    self.counter = 0
  }

  func emit(_ statement: YUL.Statement) {
    self.blockStack[blockStack.count - 1].statements.append(statement)
  }

  func withNewBlock(_ inner: () -> Void) -> YUL.Block {
    self.blockStack.append(YUL.Block([]))
    inner()
    return self.blockStack.popLast()!
  }

  func freshVariable() -> String {
    let varName = "$temp\(self.counter)"
    self.counter += 1
    return varName
  }

  func dump() -> String {
    return (self.blockStack.last!.statements.map {$0.description}).joined(separator: "\n")
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
