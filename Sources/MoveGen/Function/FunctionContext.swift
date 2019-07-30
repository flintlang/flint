//
//  Context.swift
//  MoveGen
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

  /// Stack of do-catch statements, for handling errors.
  var doCatchStatementStack: [DoCatchStatement]

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
    self.blockStack = [Block()]
    self.counter = 0
  }

  func emit(_ statement: YUL.Statement) {
    let catchableSuccesses = statement.catchableSuccesses
    if !catchableSuccesses.isEmpty {
      let allSucceeded = catchableSuccesses.reduce(.literal(.num(1)), { acc, success in
        .functionCall(FunctionCall("and", acc, success))
      })
      let allSucceededVariable = freshVariable()
      emit(.inline("let \(allSucceededVariable) := \(allSucceeded.description)"))
      emit(.inline("switch \(allSucceededVariable)"))
      emit(.inline("case 0"))
      emit(.block(withNewBlock {
        topDoCatch!.catchBody.forEach { statement in
          emit(MoveStatement(statement: statement).rendered(functionContext: self))
        }
      }))
      // Further statements will be inside this block. It will be closed
      // eventually in withNewBlock(...).
      emit(.inline("case 1"))
      _ = pushBlock()
    }
    blockStack[blockStack.count - 1].statements.append(statement)
  }

  func withNewBlock(_ inner: () -> Void) -> YUL.Block {
    // The inner() call may cause more blocks to be pushed (see emit above),
    // so here we make sure to pop and emit all the additional blocks before
    // returning this one.
    let outerCount = pushBlock()
    inner()
    while blockStack.count != outerCount {
      emit(.block(popBlock()))
    }
    return popBlock()
  }

  func pushBlock() -> Int {
    blockStack.append(Block())
    return blockStack.count
  }

  func popBlock() -> YUL.Block {
    return self.blockStack.popLast()!
  }

  func freshVariable() -> String {
    let varName = "$temp\(self.counter)"
    self.counter += 1
    return varName
  }

  /// Returns the string representation of the outer block.
  /// The FunctionContext should not be used after this is called.
  func finalise() -> String {
    return (popBlock().statements.map {$0.description}).joined(separator: "\n")
  }

  func pushDoCatch(_ doCatchStatement: DoCatchStatement) {
    doCatchStatementStack.append(doCatchStatement)
  }

  func popDoCatch() {
    _ = doCatchStatementStack.popLast()
  }

  var topDoCatch: DoCatchStatement? {
    return doCatchStatementStack.last
  }
}
