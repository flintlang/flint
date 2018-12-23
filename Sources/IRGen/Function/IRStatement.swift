//
//  IRStatement.swift
//  IRGen
//
//  Created by Franklin Schrans on 27/04/2018.
//

import AST
import CryptoSwift
import Lexer
import YUL

/// Generates code for a statement.
struct IRStatement {
  var statement: AST.Statement

  func rendered(functionContext: FunctionContext) -> YUL.Statement {
    switch statement {
    case .expression(let expression):
      return .expression(IRExpression(expression: expression, asLValue: false)
        .rendered(functionContext: functionContext))
    case .ifStatement(let ifStatement):
      return IRIfStatement(ifStatement: ifStatement).rendered(functionContext: functionContext)
    case .returnStatement(let returnStatement):
      return IRReturnStatement(returnStatement: returnStatement).rendered(functionContext: functionContext)
    case .becomeStatement(let becomeStatement):
      return IRBecomeStatement(becomeStatement: becomeStatement).rendered(functionContext: functionContext)
    case .emitStatement(let emitStatement):
      return IREmitStatement(emitStatement: emitStatement).rendered(functionContext: functionContext)
    case .forStatement(let forStatement):
      return IRForStatement(forStatement: forStatement).rendered(functionContext: functionContext)
    case .doCatchStatement(let doCatchStatement):
      return IRDoCatchStatement(doCatchStatement: doCatchStatement).rendered(functionContext: functionContext)
    }
  }
}

/// Generates code for an if statement.
struct IRIfStatement {
  var ifStatement: IfStatement

  func rendered(functionContext: FunctionContext) -> YUL.Statement {
    let condition = IRExpression(expression: ifStatement.condition).rendered(functionContext: functionContext)

    let functionContext = functionContext
    functionContext.scopeContext = ifStatement.ifBodyScopeContext!

    let body = functionContext.withNewBlock {
      ifStatement.body.forEach { statement in
        functionContext.emit(IRStatement(statement: statement).rendered(functionContext: functionContext))
      }
    }

    if !ifStatement.elseBody.isEmpty {
      functionContext.scopeContext = ifStatement.elseBodyScopeContext!
      let elseBody = functionContext.withNewBlock {
        ifStatement.elseBody.forEach { statement in
          functionContext.emit(IRStatement(statement: statement).rendered(functionContext: functionContext))
        }
      }
      return .switch(Switch(condition, cases: [(YUL.Literal.num(1), body)], default: elseBody))
    }

    return .switch(Switch(condition, cases: [(YUL.Literal.num(1), body)]))
  }
}

/// Generates code for a for statement.
struct IRForStatement {
  var forStatement: ForStatement

  func rendered(functionContext: FunctionContext) -> YUL.Statement {
    let functionContext = functionContext
    functionContext.scopeContext = forStatement.forBodyScopeContext!

    switch forStatement.iterable {
    case .identifier(let arrayIdentifier):
      return .`for`(generateArraySetupCode(prefix: "flint$\(forStatement.variable.identifier.name)$",
        iterable: arrayIdentifier, functionContext: functionContext))
    case .range(let rangeExpression):
      return .`for`(generateRangeSetupCode(iterable: rangeExpression, functionContext: functionContext))
    default:
      fatalError("The iterable \(forStatement.iterable) is not yet supported in for loops")
    }
  }

  func generateArraySetupCode(prefix: String, iterable: AST.Identifier, functionContext: FunctionContext) -> ForLoop {
    // Iterating over an array
    let isLocal = functionContext.scopeContext.containsVariableDeclaration(for: iterable.name)
    let offset: YUL.Expression
    if !isLocal,
      let intOffset = functionContext.environment.propertyOffset(for: iterable.name,
                                                                 enclosingType: functionContext.enclosingTypeName) {
      // Is contract array
      offset = .literal(.num(intOffset))
    } else if isLocal {
      offset = .identifier("_\(iterable.name)")
    } else {
      fatalError("Couldn't find offset for iterable")
    }

    let loadArrLen: YUL.Expression
    let toAssign: YUL.Expression

    let type = functionContext.environment.type(of: iterable.name,
                                                enclosingType: functionContext.enclosingTypeName,
                                                scopeContext: functionContext.scopeContext)
    switch type {
    case .arrayType:
      let arrayElementOffset = IRRuntimeFunction.storageArrayOffset(
        arrayOffset: offset, index: .identifier("\(prefix)i"))
      loadArrLen = IRRuntimeFunction.load(address: offset, inMemory: false)
      switch forStatement.variable.type.rawType {
      case .arrayType, .fixedSizeArrayType:
        toAssign = arrayElementOffset
      default:
        toAssign = IRRuntimeFunction.load(address: arrayElementOffset, inMemory: false)
      }

    case .fixedSizeArrayType:
      let typeSize = functionContext.environment.size(of: type)
      loadArrLen = .literal(.num(typeSize))
      let arrayElementOffset = IRRuntimeFunction.storageFixedSizeArrayOffset(
        arrayOffset: offset, index: .identifier("\(prefix)i"), arraySize: typeSize)
      toAssign = IRRuntimeFunction.load(address: arrayElementOffset, inMemory: false)

    case .dictionaryType:
      loadArrLen = IRRuntimeFunction.load(address: offset, inMemory: false)
      let keysArrayOffset = IRRuntimeFunction.storageDictionaryKeysArrayOffset(dictionaryOffset: offset)
      let keyOffset = IRRuntimeFunction.storageOffsetForKey(baseOffset: keysArrayOffset,
        key: .functionCall(FunctionCall("add", [.identifier("\(prefix)i"), .literal(.num(1))])))
      let key = IRRuntimeFunction.load(address: keyOffset, inMemory: false)
      let dictionaryElementOffset
        = IRRuntimeFunction.storageDictionaryOffsetForKey(dictionaryOffset: offset, key: key)
      toAssign = IRRuntimeFunction.load(address: dictionaryElementOffset, inMemory: false)

    default:
      fatalError()
    }

    let initialize = Block([.inline("""
    let \(prefix)i := 0
    let \(prefix)arrLen := \(loadArrLen)
    """)])

    let condition = YUL.Expression.functionCall(
      FunctionCall("lt", [.identifier("\(prefix)i"), .identifier("\(prefix)arrLen")]))
    let step = Block([
      .expression(.assignment(Assignment(["\(prefix)i"],
        .functionCall(FunctionCall("add", [.identifier("\(prefix)i"), .literal(.num(1))])))))
    ])

    let body = functionContext.withNewBlock {
      functionContext.emit(.expression(
        .variableDeclaration(VariableDeclaration([(forStatement.variable.identifier.name.mangled, .any)], toAssign))))
      forStatement.body.forEach { statement in
        functionContext.emit(IRStatement(statement: statement).rendered(functionContext: functionContext))
      }
    }

    return ForLoop(initialize, condition, step, body)
  }

  func generateRangeSetupCode(iterable: AST.RangeExpression, functionContext: FunctionContext) -> ForLoop {
    // Iterating over a range
    // Check valid range
    guard case .literal(let rangeStart) = iterable.initial,
      case .literal(let rangeEnd) = iterable.bound else {
        fatalError("Non-literal ranges are not supported")
    }
    guard case .literal(.decimal(.integer(let start))) = rangeStart.kind,
      case .literal(.decimal(.integer(let end))) = rangeEnd.kind else {
        fatalError("Only integer decimal ranges supported")
    }

    let ascending = start < end

    var comparisonToken: Token.Kind = ascending ? .punctuation(.lessThanOrEqual) : .punctuation(.greaterThanOrEqual)
    if case .punctuation(.halfOpenRange) = iterable.op.kind {
      comparisonToken = ascending ? .punctuation(.openAngledBracket) : .punctuation(.closeAngledBracket)
    }

    let changeToken: Token.Kind = ascending ? .punctuation(.plus) : .punctuation(.minus)

    // Create IR statements for loop sub-statements
    let initialisation = IRAssignment(lhs: .identifier(forStatement.variable.identifier), rhs: iterable.initial)
      .rendered(functionContext: functionContext, asTypeProperty: false)
    var condition = BinaryExpression(lhs: .identifier(forStatement.variable.identifier),
                                     op: Token(kind: comparisonToken, sourceLocation: forStatement.sourceLocation),
                                     rhs: .identifier(
                                      Identifier(identifierToken: Token(kind: .identifier("bound"),
                                                                        sourceLocation: forStatement.sourceLocation))))
    let change: AST.Expression = .binaryExpression(
      BinaryExpression(lhs: .identifier(forStatement.variable.identifier),
                       op: Token(kind: changeToken, sourceLocation: forStatement.sourceLocation),
                       rhs: .literal(Token(kind: .literal(.decimal(.integer(1))),
                                           sourceLocation: forStatement.sourceLocation))))
    let update = IRAssignment(lhs: .identifier(forStatement.variable.identifier), rhs: change)
      .rendered(functionContext: functionContext, asTypeProperty: false).description

    // Change <= into (< || ==)
    if [.lessThanOrEqual, .greaterThanOrEqual].contains(condition.opToken) {
      let strictOperator: Token.Kind.Punctuation =
        condition.opToken == .lessThanOrEqual ? .openAngledBracket : .closeAngledBracket

      var lhsExpression = condition
      lhsExpression.op = Token(kind: .punctuation(strictOperator), sourceLocation: lhsExpression.op.sourceLocation)

      var rhsExpression = condition
      rhsExpression.op = Token(kind: .punctuation(.doubleEqual), sourceLocation: rhsExpression.op.sourceLocation)

      condition.lhs = .binaryExpression(lhsExpression)
      condition.rhs = .binaryExpression(rhsExpression)

      let sourceLocation = condition.op.sourceLocation
      condition.op = Token(kind: .punctuation(.or), sourceLocation: sourceLocation)
    }

    let rangeExpression = IRExpression(expression: iterable.bound).rendered(functionContext: functionContext)
    let binaryExpression = IRExpression(expression: .binaryExpression(condition))
      .rendered(functionContext: functionContext)

    let initialize = Block([.inline("""
      let \(initialisation.description)
      let _bound := \(rangeExpression.description)
    """)])

    let step = Block([.inline("""
      \(update)
    """)])

    let body = functionContext.withNewBlock {
      forStatement.body.forEach { statement in
        functionContext.emit(IRStatement(statement: statement).rendered(functionContext: functionContext))
      }
    }

    return ForLoop(initialize, binaryExpression, step, body)
  }
}

/// Generates code for a return statement.
struct IRReturnStatement {
  var returnStatement: ReturnStatement

  func rendered(functionContext: FunctionContext) -> YUL.Statement {
    guard let expression = returnStatement.expression else {
      return .inline("")
    }

    let renderedExpression = IRExpression(expression: expression).rendered(functionContext: functionContext)
    return .inline("\(IRFunction.returnVariableName) := \(renderedExpression.description)")
  }
}

/// Generates code for a become statement.
struct IRBecomeStatement {
  var becomeStatement: BecomeStatement

  func rendered(functionContext: FunctionContext) -> YUL.Statement {
    let sl = becomeStatement.sourceLocation
    let stateVariable: AST.Expression = .identifier(
      Identifier(name: IRContract.stateVariablePrefix + functionContext.enclosingTypeName,
                 sourceLocation: .DUMMY))
    let selfState: AST.Expression = .binaryExpression(
      BinaryExpression(lhs: .self(Token(kind: .self, sourceLocation: sl)),
                       op: Token(kind: .punctuation(.dot), sourceLocation: sl),
                       rhs: stateVariable))

    let assignState: AST.Expression = .binaryExpression(
      BinaryExpression(lhs: selfState,
                       op: Token(kind: .punctuation(.equal), sourceLocation: sl),
                       rhs: becomeStatement.expression))

    return .inline(IRExpression(expression: assignState).rendered(functionContext: functionContext).description)
  }
}

/// Generates code for an emit statement.
struct IREmitStatement {
  var emitStatement: EmitStatement

  func rendered(functionContext: FunctionContext) -> YUL.Statement {
    return .inline(IRFunctionCall(functionCall: emitStatement.functionCall)
      .rendered(functionContext: functionContext).description)
  }
}

struct IRDoCatchStatement {
  var doCatchStatement: DoCatchStatement

  func rendered(functionContext: FunctionContext) -> YUL.Statement {
    functionContext.pushDoCatch(doCatch: doCatchStatement)
    //let ret: YUL.Statement = .block(functionContext.withNewBlock {
      doCatchStatement.doBody.forEach { statement in
        functionContext.emit(IRStatement(statement: statement).rendered(functionContext: functionContext))
      }
    //})
    functionContext.popDoCatch()
    return .noop //ret
  }
}
