//
//  MoveStatement.swift
//  MoveGen
//
//  Created by Franklin Schrans on 27/04/2018.
//

import AST
import CryptoSwift
import Lexer
import MoveIR

/// Generates code for a statement.
struct MoveStatement {
  var statement: AST.Statement

  func rendered(functionContext: FunctionContext) -> MoveIR.Statement {
    switch statement {
    case .expression(let expression):
      return .expression(MoveExpression(expression: expression, position: .normal)
        .rendered(functionContext: functionContext))
    case .ifStatement(let ifStatement):
      return MoveIfStatement(ifStatement: ifStatement).rendered(functionContext: functionContext)
    case .returnStatement(let returnStatement):
      return MoveReturnStatement(returnStatement: returnStatement).rendered(functionContext: functionContext)
    case .becomeStatement(let becomeStatement):
      return MoveBecomeStatement(becomeStatement: becomeStatement).rendered(functionContext: functionContext)
    case .emitStatement(let emitStatement):
      return MoveEmitStatement(emitStatement: emitStatement).rendered(functionContext: functionContext)
    case .forStatement(let forStatement):
      return MoveForStatement(forStatement: forStatement).rendered(functionContext: functionContext)
    case .doCatchStatement(let doCatchStatement):
      return MoveDoCatchStatement(doCatchStatement: doCatchStatement).rendered(functionContext: functionContext)
    }
  }
}

/// Generates code for an if statement.
struct MoveIfStatement {
  var ifStatement: IfStatement

  func rendered(functionContext: FunctionContext) -> MoveIR.Statement {
    let condition = MoveExpression(expression: ifStatement.condition).rendered(functionContext: functionContext)

    let outerParameters = functionContext.scopeContext.parameters
    let functionContext = functionContext
    functionContext.scopeContext = ifStatement.ifBodyScopeContext!
    functionContext.scopeContext.parameters = outerParameters

    let body = functionContext.withNewBlock {
      ifStatement.body.forEach { statement in
        functionContext.emit(MoveStatement(statement: statement).rendered(functionContext: functionContext))
      }
    }

    if !ifStatement.elseBody.isEmpty {
      functionContext.scopeContext = ifStatement.elseBodyScopeContext!
      functionContext.scopeContext.parameters = outerParameters
      let elseBody = functionContext.withNewBlock {
        ifStatement.elseBody.forEach { statement in
          functionContext.emit(MoveStatement(statement: statement).rendered(functionContext: functionContext))
        }
      }
      return .if(If(condition, body, elseBody))
    }

    return .if(If(condition, body, nil))
  }
}

/// Generates code for a for statement.
struct MoveForStatement {
  var forStatement: ForStatement

  func rendered(functionContext: FunctionContext) -> MoveIR.Statement {
    let outerParameters = functionContext.scopeContext.parameters
    let functionContext = functionContext
    functionContext.scopeContext = forStatement.forBodyScopeContext!
    functionContext.scopeContext.parameters = outerParameters

    switch forStatement.iterable {
    case .range(let rangeExpression):
      if case .literal = rangeExpression.initial,
         case .literal = rangeExpression.bound {
        return .for(generateRangeSetupCode(iterable: rangeExpression, functionContext: functionContext))
      } else {
        // Can easily be done by branching, but not currently permitted in the parser
        fatalError("Flint doesn't currently support variable ranges")
      }
    default:
      fatalError("The iterable \(forStatement.iterable) is not yet supported in for loops")
    }
  }

  func generateRangeSetupCode(iterable: AST.RangeExpression, functionContext: FunctionContext) -> ForLoop {
    guard case .literal(let initialToken) = iterable.initial,
          case .literal(let boundToken) = iterable.bound,
          case .literal(.decimal(.integer(let start))) = initialToken.kind,
          case .literal(.decimal(.integer(let end))) = boundToken.kind else {
      // Can easily be done by branching, but not currently permitted in the parser
      fatalError("Flint doesn't currently support variable ranges")
    }

    let accumulate = start <= end
    let comparison = accumulate
        ? (iterable.op.kind == .punctuation(.halfOpenRange) ? Operation.lessThan : Operation.lessThanOrEqual)
        : (iterable.op.kind == .punctuation(.halfOpenRange) ? Operation.greaterThan : Operation.greaterThanOrEqual)
    let nextStep = accumulate ? Operation.add : Operation.subtract

    let incrementor: MoveIR.Expression = MoveIdentifier(identifier: forStatement.variable.identifier)
        .rendered(functionContext: functionContext)
    let incrementorName = Mangler.mangleName(forStatement.variable.identifier.name)

    var initialize = MoveIR.Statement.expression(.assignment(Assignment(
        incrementorName,
        MoveExpression(expression: iterable.initial).rendered(functionContext: functionContext)
    )))
    let condition = MoveIR.Expression.operation(comparison(
        incrementor,
        MoveExpression(expression: iterable.bound).rendered(functionContext: functionContext)
    ))
    var body = Block()
    body.statements = forStatement.body.map { (statement: AST.Statement) in
      return MoveStatement(statement: statement).rendered(functionContext: functionContext)
    }
    let step = MoveIR.Statement.expression(.assignment(Assignment(
        incrementorName,
        .operation(nextStep(incrementor, .literal(.num(1)))))))
    return ForLoop(Block(initialize), condition, Block(step), body)
  }
}

/// Generates code for a return statement.
struct MoveReturnStatement {
  var returnStatement: ReturnStatement

  func rendered(functionContext: FunctionContext) -> MoveIR.Statement {
    guard let expression = returnStatement.expression else {
      functionContext.emitReleaseReferences()
      return .inline("return")
    }

    let returnVariableIdentifier: AST.Identifier
      = .init(name: MoveFunction.returnVariableName, sourceLocation: returnStatement.sourceLocation)
    let renderedExpression = MoveExpression(expression: expression).rendered(functionContext: functionContext)
    functionContext.emit(.expression(.assignment(Assignment(returnVariableIdentifier.name, renderedExpression))))
    for statement: AST.Statement in returnStatement.cleanupStatements ?? [] {
      functionContext.emit(MoveStatement(statement: statement).rendered(functionContext: functionContext))
    }
    functionContext.emitReleaseReferences()
    return .inline("return move(\(returnVariableIdentifier.name))")
  }
}

/// Generates code for a become statement.
struct MoveBecomeStatement {
  var becomeStatement: BecomeStatement

  func rendered(functionContext: FunctionContext) -> MoveIR.Statement {
    let sl = becomeStatement.sourceLocation
    let stateVariable: AST.Expression = .identifier(
      Identifier(name: MoveContract.stateVariablePrefix + functionContext.enclosingTypeName,
                 sourceLocation: sl,
                 enclosingType: functionContext.enclosingTypeName))
    let selfState: AST.Expression = .binaryExpression(
      BinaryExpression(lhs: .`self`(Token(kind: .`self`, sourceLocation: sl)),
                       op: Token(kind: .punctuation(.dot), sourceLocation: sl),
                       rhs: stateVariable))

    let assignState: AST.Expression = .binaryExpression(
      BinaryExpression(lhs: selfState,
                       op: Token(kind: .punctuation(.equal), sourceLocation: sl),
                       rhs: becomeStatement.expression))

    return .inline(MoveExpression(expression: assignState).rendered(functionContext: functionContext).description)
  }
}

/// Generates code for an emit statement.
struct MoveEmitStatement {
  var emitStatement: EmitStatement

  func rendered(functionContext: FunctionContext) -> MoveIR.Statement {
    return .inline(MoveFunctionCall(functionCall: emitStatement.functionCall)
      .rendered(functionContext: functionContext).description)
  }
}

struct MoveDoCatchStatement {
  var doCatchStatement: DoCatchStatement

  func rendered(functionContext: FunctionContext) -> MoveIR.Statement {
    functionContext.pushDoCatch(doCatchStatement)
    let ret: MoveIR.Statement = .block(functionContext.withNewBlock {
      doCatchStatement.doBody.forEach { statement in
        functionContext.emit(MoveStatement(statement: statement).rendered(functionContext: functionContext))
      }
    })
    functionContext.popDoCatch()
    return ret
  }
}
