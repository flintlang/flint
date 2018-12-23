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

  /// Stack of do-catch statements, each with the number of errors handled.
  var doCatchStatementStack: [DoCatchStatementStackElement]

  /// Stack of code blocks ({ ... })
  var blockStack: [YUL.Block]

  /// Fresh variable counter.
  private var counter: Int

  init(environment: Environment,
       scopeContext: ScopeContext,
       enclosingTypeName: String,
       isInStructFunction: Bool) {
    self.environment = environment
    self.scopeContext = scopeContext
    self.enclosingTypeName = enclosingTypeName
    self.isInStructFunction = isInStructFunction

    self.doCatchStatementStack = []
    self.blockStack = [YUL.Block([])]
    self.counter = 0
  }

  func emit(_ statement: YUL.Statement) {
    let catchableSuccesses = statement.catchableSuccesses
    if catchableSuccesses.count > 0 {
      let allSucceeded = catchableSuccesses.reduce(.literal(.num(1)), { acc, success in
        .functionCall(FunctionCall("and", [acc, success]))
      })
      emit(.inline("switch (\(allSucceeded.description))"))
      emit(.inline("case (0)"))
      emit(.block(withNewBlock {
        topDoCatch!.doCatchStatement.catchBody.forEach { statement in
          emit(IRStatement(statement: statement).rendered(functionContext: self))
        }
      }))
      emit(.inline("case (1)"))
      pushBlock()
      doCatchStatementStack[doCatchStatementStack.count - 1].catchCount += 1
    }
    self.blockStack[blockStack.count - 1].statements.append(statement)
  }

  func withNewBlock(_ inner: () -> Void) -> YUL.Block {
    pushBlock()
    inner()
    return popBlock()
  }

  func pushBlock() {
    self.blockStack.append(YUL.Block([]))
  }

  func popBlock() -> YUL.Block {
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

  func pushDoCatch(doCatch: DoCatchStatement) {
    doCatchStatementStack.append(DoCatchStatementStackElement(doCatchStatement: doCatch))
  }

  func popDoCatch() {
    let top = doCatchStatementStack.popLast()!
    if top.catchCount > 0 {
      for _ in 1...top.catchCount {
        emit(.block(popBlock()))
      }
    }
  }

  var topDoCatch: DoCatchStatementStackElement? {
    return doCatchStatementStack.last
  }
}

struct DoCatchStatementStackElement {
  let doCatchStatement: DoCatchStatement
  var catchCount: Int

  init(doCatchStatement: DoCatchStatement) {
    self.doCatchStatement = doCatchStatement
    catchCount = 0
  }
}
