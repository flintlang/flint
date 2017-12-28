//
//  IULIAFunction.swift
//  IULIABackend
//
//  Created by Franklin Schrans on 12/28/17.
//

import AST

struct IULIAFunction {
  static let returnVariableName = "ret"

  var functionDeclaration: FunctionDeclaration
  var callerCapabilities: [CallerCapability]

  func rendered() -> String {
    let name = functionDeclaration.identifier.name
    let parameters = functionDeclaration.parameters.map({ $0.identifier.name })
    let doesReturn = functionDeclaration.resultType != nil
    let parametersString = parameters.joined(separator: ",")
    let signature = "\(name)(\(parametersString)) \(doesReturn ? "-> \(IULIAFunction.returnVariableName)" : "")"

    let body = functionDeclaration.body.map({ IULIAFunction.render($0) }).joined(separator: "\n")

    return """
    \(signature) {
      \(body)
    }
    """
  }

  func mangledSignature() -> String {
    let name = functionDeclaration.identifier.name
    let parameters = functionDeclaration.parameters.map({ canonicalize($0.type) })
    let parametersString = parameters.joined(separator: ",")

    return "\(name)(\(parametersString))"
  }

  func canonicalize(_ type: Type) -> String {
    return type.name
  }
}

extension IULIAFunction {
  static func render(_ statement: AST.Statement) -> String {
    switch statement {
    case .expression(let expression): return render(expression)
    case .ifStatement(let ifStatement): return render(ifStatement)
    case .returnStatement(let returnStatement): return render(returnStatement)
    }
  }

  static func render(_ expression: Expression) -> String {
    switch expression {
    case .binaryExpression(let binaryExpression): return render(binaryExpression)
    case .bracketedExpression(let expression): return render(expression)
    case .functionCall(let functionCall): return render(functionCall)
    case .identifier(let identifier): return render(identifier)
    case .variableDeclaration(_): fatalError("Local vars not yet implemented")
    case .literal(let literal): return render(literal)
    }
  }

  static func render(_ binaryExpression: BinaryExpression) -> String {
    switch binaryExpression.op {
    case .equal:
      return "\(render(binaryExpression.lhs)) := \(render(binaryExpression.rhs))"
    default:
      return ""
//      fatalError("Operator \(binaryExpression.op) not yet implemented.")
    }
  }

  static func render(_ functionCall: FunctionCall) -> String {
    let args: String = functionCall.arguments.map({ render($0) }).joined(separator: ",")
    return "\(functionCall.identifier)(\(args))"
  }

  static func render(_ identifier: Identifier) -> String {
    return identifier.name
  }

  static func render(_ literal: Token.Literal) -> String {
    switch literal {
    case .boolean(let boolean): return boolean.rawValue
    case .decimal(.real(let num1, let num2)): return "\(num1).\(num2)"
    case .decimal(.integer(let num)): return "\(num)"
    case .string(let string): return "\"\(string)\""
    }
  }

  static func render(_ ifStatement: IfStatement) -> String {
    let condition = render(ifStatement.condition)
    let body = ifStatement.statements.map({ render($0) }).joined(separator: "\n")
    let elseBody = ifStatement.elseClauseStatements.map({ render($0) }).joined(separator: "\n")

    let ifCode = """
    if \(condition) {
      \(body)
    }
    """

    let elseCode: String?
    if !elseBody.isEmpty {
      elseCode = """
        else {
        \(elseBody)
      }
      """
    } else {
      elseCode = nil
    }

    return ifCode + (elseCode ?? "")
  }

  static func render(_ returnStatement: ReturnStatement) -> String {
    guard let expression = returnStatement.expression else {
      return ""
    }

    return "\(returnVariableName) := \(render(expression))"
  }
}
