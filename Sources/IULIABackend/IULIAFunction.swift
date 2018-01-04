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

  var propertyMap: [String: Int]

  var name: String {
    return functionDeclaration.identifier.name
  }

  var parameterNames: [String] {
    return functionDeclaration.parameters.map({ mangleParameterName($0.identifier.name) })
  }

  var parameterCanonicalTypes: [CanonicalType] {
    return functionDeclaration.parameters.map({ CanonicalType(from: $0.type)! })
  }

  var resultCanonicalType: CanonicalType? {
    return functionDeclaration.resultType.flatMap({ CanonicalType(from: $0)! })
  }

  func rendered() -> String {
    let doesReturn = functionDeclaration.resultType != nil
    let parametersString = parameterNames.joined(separator: ", ")
    let signature = "\(name)(\(parametersString)) \(doesReturn ? "-> \(IULIAFunction.returnVariableName)" : "")"

    let body = functionDeclaration.body.map({ render($0) }).joined(separator: "\n")

    return """
    function \(signature) {
      \(body.indented(by: 2))
    }
    """
  }

  func mangledSignature() -> String {
    let name = functionDeclaration.identifier.name
    let parametersString = parameterCanonicalTypes.map({ $0.rawValue }).joined(separator: ",")

    return "\(name)(\(parametersString))"
  }

  func mangleParameterName(_ name: String) -> String {
    return "_\(name)"
  }
}

extension IULIAFunction {
  func render(_ statement: AST.Statement) -> String {
    switch statement {
    case .expression(let expression): return render(expression)
    case .ifStatement(let ifStatement): return render(ifStatement)
    case .returnStatement(let returnStatement): return render(returnStatement)
    }
  }

  func render(_ expression: Expression, asLValue: Bool = false) -> String {
    switch expression {
    case .binaryExpression(let binaryExpression): return render(binaryExpression)
    case .bracketedExpression(let expression): return render(expression)
    case .functionCall(let functionCall): return render(functionCall)
    case .identifier(let identifier): return render(identifier, asLValue: asLValue)
    case .variableDeclaration(_): fatalError("Local vars not yet implemented")
    case .literal(let literal): return render(literal)
    }
  }

  func render(_ binaryExpression: BinaryExpression) -> String {
    let lhs = render(binaryExpression.lhs)
    let rhs = render(binaryExpression.rhs)
    
    switch binaryExpression.opToken {
    case .equal: return "sstore(\(render(binaryExpression.lhs, asLValue: true)), \(rhs))"
    case .plus: return "add(\(lhs), \(rhs))"
    case .minus: return "sub(\(lhs), \(rhs))"
    case .times: return "mul(\(lhs), \(rhs))"
    case .divide: return "div(\(lhs), \(rhs))"
    case .lessThan: return "lt(\(lhs), \(rhs))"
    case .lessThanOrEqual: return "le(\(lhs), \(rhs))"
    case .greaterThan: return "gt(\(lhs), \(rhs))"
    case .greaterThanOrEqual: return "ge(\(lhs), \(rhs))"

    default:
      fatalError("Operator \(binaryExpression.op) not yet implemented.")
    }
  }

  func render(_ functionCall: FunctionCall) -> String {
    let args: String = functionCall.arguments.map({ render($0) }).joined(separator: ", ")
    return "\(functionCall.identifier.name)(\(args))"
  }

  func render(_ identifier: Identifier, asLValue: Bool) -> String {
    guard !asLValue else {
      return "\(propertyMap[identifier.name]!)"
    }

    let mangledName = mangleParameterName(identifier.name)
    if parameterNames.contains(mangledName) {
      return mangledName
    }

    return "sload(\(propertyMap[identifier.name]!))"
  }

  func render(_ literalToken: Token) -> String {
    guard case .literal(let literal) = literalToken.kind else {
      fatalError("Unexpected token \(literalToken.kind).")
    }

    switch literal {
    case .boolean(let boolean): return boolean.rawValue
    case .decimal(.real(let num1, let num2)): return "\(num1).\(num2)"
    case .decimal(.integer(let num)): return "\(num)"
    case .string(let string): return "\"\(string)\""
    }
  }

  func render(_ ifStatement: IfStatement) -> String {
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

  func render(_ returnStatement: ReturnStatement) -> String {
    guard let expression = returnStatement.expression else {
      return ""
    }

    return "\(IULIAFunction.returnVariableName) := \(render(expression))"
  }
}
