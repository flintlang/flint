//
//  Context.swift
//  MoveGen
//
//  Created by Franklin Schrans on 27/04/2018.
//

import MoveIR
import AST
import Lexer

/// Context used when generating code the body of a function.
class FunctionContext: CustomStringConvertible {
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
  var blockStack: [MoveIR.Block]

  /// Move Constructors are WEIrd
  var isConstructor: Bool

  /// Fresh variable counter.
  private var counter: Int

  var selfType: RawType {
    return scopeContext.type(for: "self") ?? environment.type(of: .`self`(Token.DUMMY),
                                                              enclosingType: enclosingTypeName,
                                                              scopeContext: scopeContext)
  }

  init(environment: Environment,
       scopeContext: ScopeContext,
       enclosingTypeName: String,
       isInStructFunction: Bool = false,
       isConstructor: Bool = false) {
    self.environment = environment
    self.scopeContext = scopeContext
    self.enclosingTypeName = enclosingTypeName
    self.isInStructFunction = isInStructFunction

    self.doCatchStatementStack = []
    self.blockStack = [Block()]
    self.counter = 0
    self.isConstructor = isConstructor
  }

  func emit(_ statement: MoveIR.Statement, at: Int? = nil) {
    let catchableSuccesses = statement.catchableSuccesses
    if !catchableSuccesses.isEmpty {
      let allSucceeded = catchableSuccesses.reduce(.literal(.num(1)), { acc, success in
        .functionCall(FunctionCall("and", acc, success))
      })
      let allSucceededVariable = freshVariable()
      emit(.inline("let \(allSucceededVariable) = \(allSucceeded.description);"))
      emit(.inline("functionContextSwitch \(allSucceededVariable)"))
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
    if let position = at {
      blockStack[blockStack.count - 1].statements.insert(statement, at: position)
    } else {
      blockStack[blockStack.count - 1].statements.append(statement)
    }
  }

  func withNewBlock(_ inner: () -> Void) -> MoveIR.Block {
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

  func popBlock() -> MoveIR.Block {
    return self.blockStack.popLast()!
  }

  func freshVariable() -> String {
    let varName = "$temp$functionContext$\(self.counter)"
    self.counter += 1
    return varName
  }

  /// Returns the string representation of the outer block.
  /// The FunctionContext should not be used after this is called.
  func finalise() -> String {
    return (popBlock().statements.map { $0.description }).joined(separator: "\n")
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

  func isReferenceParameter(identifier: AST.Identifier) -> Bool {
    return scopeContext.parameters.contains(where: { (parameter: Parameter) in
      if parameter.identifier.name == identifier.name {
        if parameter.isInout {
          return true
        } else if let type = CanonicalType(from: parameter.type.rawType, environment: environment),
                  case .resource = type {
          return true
        }
      }
      return false
    })
  }

  public var description: String {
    return
        """
        FunctionContext {
          environment: \(environment)
          scopeContext: \(scopeContext)
          enclosingTypeName: \(enclosingTypeName)
          isInStructFunction: \(isInStructFunction)
          doCatchStatementStack: \(doCatchStatementStack)
          blockStack: \(blockStack)
          isConstructor: \(isConstructor)
          counter: \(counter)
        }
        """
  }

  public func emitReleaseReferences() {
    let referencesToRelease: [AST.Identifier] = scopeContext.parameters
        .filter { $0.isInout }
        .map { $0.identifier }
    for reference in referencesToRelease {
      let referenceExpression: MoveIR.Expression
          = MoveIdentifier(identifier: reference).rendered(functionContext: self, forceMove: true)
      self.emit(.inline("_ = \(referenceExpression)"))
    }
  }
}
