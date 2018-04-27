//
//  IULIAStatement.swift
//  IRGen
//
//  Created by Franklin Schrans on 27/04/2018.
//

import AST

/// Generates code for a statement.
struct IULIAStatement {
  var statement: Statement
  
  func rendered(functionContext: FunctionContext) -> String {
    switch statement {
    case .expression(let expression): return IULIAExpression(expression: expression, asLValue: false).rendered(functionContext: functionContext)
    case .ifStatement(let ifStatement): return IULIAIfStatement(ifStatement: ifStatement).rendered(functionContext: functionContext)
    case .returnStatement(let returnStatement): return IULIAReturnStatement(returnStatement: returnStatement).rendered(functionContext: functionContext)
    }
  }
}

/// Generates code for an if statement.
struct IULIAIfStatement {
  var ifStatement: IfStatement

  func rendered(functionContext: FunctionContext) -> String {
    let condition = IULIAExpression(expression: ifStatement.condition).rendered(functionContext: functionContext)
    let body = ifStatement.body.map { statement in
      return IULIAStatement(statement: statement).rendered(functionContext: functionContext)
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
      let body = ifStatement.elseBody.map { statement in
        if case .returnStatement(_) = statement {
          fatalError("Return statements in else blocks are not supported yet")
        }
        return IULIAStatement(statement: statement).rendered(functionContext: functionContext)
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

/// Generates code for a return statement.
struct IULIAReturnStatement {
  var returnStatement: ReturnStatement
  
  func rendered(functionContext: FunctionContext) -> String {
    guard let expression = returnStatement.expression else {
      return ""
    }

    let renderedExpression = IULIAExpression(expression: expression).rendered(functionContext: functionContext)
    return "\(IULIAFunction.returnVariableName) := \(renderedExpression)"
  }
}
