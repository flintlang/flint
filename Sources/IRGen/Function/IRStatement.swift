//
//  IRStatement.swift
//  IRGen
//
//  Created by Franklin Schrans on 27/04/2018.
//

import AST
import Lexer

/// Generates code for a statement.
struct IRStatement {
  var statement: Statement

  func rendered(functionContext: FunctionContext) -> String {
    switch statement {
    case .expression(let expression):
      return IRExpression(expression: expression, asLValue: false).rendered(functionContext: functionContext)
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
    case .externalCall(let externalCall):
      return IRExternalCallStatement(externalCall: externalCall).rendered(functionContext: functionContext)
    }
  }
}

/// Generates code for an if statement.
struct IRIfStatement {
  var ifStatement: IfStatement

  func rendered(functionContext: FunctionContext) -> String {
    let condition = IRExpression(expression: ifStatement.condition).rendered(functionContext: functionContext)

    var functionContext = functionContext
    functionContext.scopeContext = ifStatement.ifBodyScopeContext!

    let body = ifStatement.body.map { statement in
      return IRStatement(statement: statement).rendered(functionContext: functionContext)
      }.joined(separator: "\n")
    let ifCode: String

    ifCode = """
    switch \(condition)
    case 1 {
      \(body.indented(by: 2))
    }
    """

    var elseCode = ""

    if !ifStatement.elseBody.isEmpty {
      functionContext.scopeContext = ifStatement.elseBodyScopeContext!
      let body = ifStatement.elseBody.map { statement in
        if case .returnStatement(_) = statement {
          fatalError("Return statements in else blocks are not supported yet")
        }
        return IRStatement(statement: statement).rendered(functionContext: functionContext)
        }.joined(separator: "\n")
      elseCode = """
      default {
        \(body.indented(by: 2))
      }
      """
    }

    return ifCode + "\n" + elseCode
  }
}

/// Generates code for a for statement.
struct IRForStatement {
  var forStatement: ForStatement

  func rendered(functionContext: FunctionContext) -> String {
    var functionContext = functionContext
    functionContext.scopeContext = forStatement.forBodyScopeContext!

    let setup: String

    switch forStatement.iterable {
    case .identifier(let arrayIdentifier):
      setup = generateArraySetupCode(prefix: "flint$\(forStatement.variable.identifier.name)$",
        iterable: arrayIdentifier, functionContext: functionContext)
    case .range(let rangeExpression):
      setup = generateRangeSetupCode(iterable: rangeExpression, functionContext: functionContext)
    default:
      fatalError("The iterable \(forStatement.iterable) is not yet supported in for loops")
    }

    let body = forStatement.body.map { statement in
      return IRStatement(statement: statement).rendered(functionContext: functionContext)
      }.joined(separator: "\n")

    return """
    for \(setup)
      \(body.indented(by: 2))
    }
    """
  }

  func generateArraySetupCode(prefix: String, iterable: Identifier, functionContext: FunctionContext) -> String {
    // Iterating over an array
    let isLocal = functionContext.scopeContext.containsVariableDeclaration(for: iterable.name)
    let offset: String
    if !isLocal,
      let intOffset = functionContext.environment.propertyOffset(for: iterable.name,
                                                                 enclosingType: functionContext.enclosingTypeName) {
      // Is contract array
        offset = String(intOffset)
    } else if isLocal {
      offset = "_\(iterable.name)"
    } else {
      fatalError("Couldn't find offset for iterable")
    }

    let loadArrLen: String
    let toAssign: String

    let type = functionContext.environment.type(of: iterable.name,
                                                enclosingType: functionContext.enclosingTypeName,
                                                scopeContext: functionContext.scopeContext)
    switch type {
    case .arrayType:
      let arrayElementOffset = IRRuntimeFunction.storageArrayOffset(arrayOffset: offset, index: "\(prefix)i")
      loadArrLen = IRRuntimeFunction.load(address: offset, inMemory: false)
      switch forStatement.variable.type.rawType {
      case .arrayType, .fixedSizeArrayType:
        toAssign = String(arrayElementOffset)
      default:
        toAssign = IRRuntimeFunction.load(address: arrayElementOffset, inMemory: false)
      }

    case .fixedSizeArrayType:
      let typeSize = functionContext.environment.size(of: type)
      loadArrLen = String(typeSize)
      let arrayElementOffset =
        IRRuntimeFunction.storageFixedSizeArrayOffset(arrayOffset: offset, index: "\(prefix)i", arraySize: typeSize)
      toAssign = IRRuntimeFunction.load(address: arrayElementOffset, inMemory: false)

    case .dictionaryType:
      loadArrLen = IRRuntimeFunction.load(address: offset, inMemory: false)
      let keysArrayOffset = IRRuntimeFunction.storageDictionaryKeysArrayOffset(dictionaryOffset: offset)
      let keyOffset = IRRuntimeFunction.storageOffsetForKey(baseOffset: keysArrayOffset, key: "add(\(prefix)i, 1)")
      let key = IRRuntimeFunction.load(address: keyOffset, inMemory: false)
      let dictionaryElementOffset = IRRuntimeFunction.storageDictionaryOffsetForKey(dictionaryOffset: offset, key: key)
      toAssign = IRRuntimeFunction.load(address: dictionaryElementOffset, inMemory: false)

    default:
      fatalError()
    }

    let variableUse = IRAssignment(lhs: .identifier(forStatement.variable.identifier),
                                   rhs: .rawAssembly(toAssign, resultType: nil))
      .rendered(functionContext: functionContext, asTypeProperty: false)

    return """
    {
    let \(prefix)i := 0
    let \(prefix)arrLen := \(loadArrLen)
    } lt(\(prefix)i, \(prefix)arrLen) { \(prefix)i := add(\(prefix)i, 1) } {
      let \(variableUse)
    """
  }

  func generateRangeSetupCode(iterable: AST.RangeExpression, functionContext: FunctionContext) -> String {
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
    let change: Expression = .binaryExpression(
      BinaryExpression(lhs: .identifier(forStatement.variable.identifier),
                       op: Token(kind: changeToken, sourceLocation: forStatement.sourceLocation),
                       rhs: .literal(Token(kind: .literal(.decimal(.integer(1))),
                                           sourceLocation: forStatement.sourceLocation))))
    let update = IRAssignment(lhs: .identifier(forStatement.variable.identifier), rhs: change)
      .rendered(functionContext: functionContext, asTypeProperty: false)

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

    return """
    {
    let \(initialisation)
    let _bound := \(rangeExpression)
    } \(binaryExpression) { \(update) } {
    """
  }
}

/// Generates code for a return statement.
struct IRReturnStatement {
  var returnStatement: ReturnStatement

  func rendered(functionContext: FunctionContext) -> String {
    guard let expression = returnStatement.expression else {
      return ""
    }

    let renderedExpression = IRExpression(expression: expression).rendered(functionContext: functionContext)
    return "\(IRFunction.returnVariableName) := \(renderedExpression)"
  }
}

/// Generates code for a become statement.
struct IRBecomeStatement {
  var becomeStatement: BecomeStatement

  func rendered(functionContext: FunctionContext) -> String {
    let sl = becomeStatement.sourceLocation
    let stateVariable: Expression = .identifier(
      Identifier(name: IRContract.stateVariablePrefix + functionContext.enclosingTypeName,
                 sourceLocation: .DUMMY))
    let selfState: Expression = .binaryExpression(
      BinaryExpression(lhs: .self(Token(kind: .self, sourceLocation: sl)),
                       op: Token(kind: .punctuation(.dot), sourceLocation: sl),
                       rhs: stateVariable))

    let assignState: Expression = .binaryExpression(
      BinaryExpression(lhs: selfState,
                       op: Token(kind: .punctuation(.equal), sourceLocation: sl),
                       rhs: becomeStatement.expression))

    return IRExpression(expression: assignState).rendered(functionContext: functionContext)
  }
}

/// Generates code for an emit statement.
struct IREmitStatement {
  var emitStatement: EmitStatement

  func rendered(functionContext: FunctionContext) -> String {
    return IRFunctionCall(functionCall: emitStatement.functionCall).rendered(functionContext: functionContext)
  }
}

struct IRDoCatchStatement {
  var doCatchStatement: DoCatchStatement

  func rendered(functionContext: FunctionContext) -> String {
    functionContext.push(doCatch: doCatchStatement)
    let code = doCatchStatement.doBody.reversed().reduce("", { acc, statement in
      switch statement {
      case .expression(.functionCall):
        var elseCode = ""
        if let elseBlock = functionContext.top {
          elseCode = elseBlock.catchBody.map { statement in
            return IRStatement(statement: statement).rendered(functionContext: functionContext)
          }.joined(separator: "\n")
        } else {
          elseCode = ""
        }

        return """
        if (true) {
          \(acc.indented(by: 2))
        } else {
          \(elseCode.indented(by: 2))
        }
        """
      default:
        return IRStatement(statement: statement).rendered(functionContext: functionContext) + "\n" + acc
      }
    })
    functionContext.pop()
    return code
  }
}

/// Generates code for an external call.
struct IRExternalCallStatement {
  var externalCall: ExternalCall

  func rendered(functionContext: FunctionContext) -> String {
    fatalError()
  }
}
