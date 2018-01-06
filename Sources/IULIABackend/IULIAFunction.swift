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
  var contractIdentifier: Identifier
  var callerCapabilities: [CallerCapability]

  var contractStorage: ContractStorage
  var context: Context

  var name: String {
    return functionDeclaration.identifier.name
  }

  var parameterNames: [String] {
    return functionDeclaration.parameters.map({ render($0.identifier) })
  }

  var parameterCanonicalTypes: [CanonicalType] {
    return functionDeclaration.parameters.map({ CanonicalType(from: $0.type.rawType)! })
  }

  var resultCanonicalType: CanonicalType? {
    return functionDeclaration.resultType.flatMap({ CanonicalType(from: $0.rawType)! })
  }

  func rendered() -> String {
    let doesReturn = functionDeclaration.resultType != nil
    let parametersString = parameterNames.joined(separator: ", ")
    let signature = "\(name)(\(parametersString)) \(doesReturn ? "-> \(IULIAFunction.returnVariableName)" : "")"

    let callerCapabilityChecks = renderCallerCapabilityChecks(callerCapabilities: callerCapabilities)
    let body = functionDeclaration.body.map({ render($0) }).joined(separator: "\n")

    return """
    function \(signature) {
      \(callerCapabilityChecks.indented(by: 2))\(body.indented(by: 2))
    }
    """
  }

  func mangledSignature() -> String {
    let name = functionDeclaration.identifier.name
    let parametersString = parameterCanonicalTypes.map({ $0.rawValue }).joined(separator: ",")

    return "\(name)(\(parametersString))"
  }

  func mangleIdentifierName(_ name: String) -> String {
    return "_\(name)"
  }

  func renderCallerCapabilityChecks(callerCapabilities: [CallerCapability]) -> String {
    let code = callerCapabilities.flatMap { callerCapability in
      guard !callerCapability.isAny else { return nil }
      let offset = contractStorage.offset(for: callerCapability.name)
      return """
      \(IULIAUtilFunction.checkCallerCapability.rawValue)(sload(\(offset)))
      """
    }

    if !code.isEmpty {
      return code.joined(separator: "\n") + "\n"
    }

    return ""
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
    case .binaryExpression(let binaryExpression): return render(binaryExpression, asLValue: asLValue)
    case .bracketedExpression(let expression): return render(expression)
    case .functionCall(let functionCall): return render(functionCall)
    case .identifier(let identifier): return render(identifier, asLValue: asLValue)
    case .variableDeclaration(let variableDeclaration): return render(variableDeclaration)
    case .literal(let literal): return render(literalToken: literal)
    case .self(let `self`): return render(selfToken: self)
    case .arrayAccess(let arrayAccess): return render(arrayAccess, asLValue: asLValue)
    }
  }

  func render(_ binaryExpression: BinaryExpression, asLValue: Bool) -> String {
    let lhs = render(binaryExpression.lhs, asLValue: asLValue)
    let rhs = render(binaryExpression.rhs, asLValue: asLValue)
    
    switch binaryExpression.opToken {
    case .equal: return renderAssignment(lhs: binaryExpression.lhs, rhs: binaryExpression.rhs)
    case .plus: return "add(\(lhs), \(rhs))"
    case .minus: return "sub(\(lhs), \(rhs))"
    case .times: return "mul(\(lhs), \(rhs))"
    case .divide: return "div(\(lhs), \(rhs))"
    case .lessThan: return "lt(\(lhs), \(rhs))"
    case .lessThanOrEqual: return "le(\(lhs), \(rhs))"
    case .greaterThan: return "gt(\(lhs), \(rhs))"
    case .greaterThanOrEqual: return "ge(\(lhs), \(rhs))"
    case .dot: return renderPropertyAccess(lhs: binaryExpression.lhs, rhs: binaryExpression.rhs, asLValue: asLValue)
    }
  }

  func renderAssignment(lhs: Expression, rhs: Expression) -> String {
    let rhsCode = render(rhs)

    switch lhs {
    case .variableDeclaration(let variableDeclaration):
      return "let \(mangleIdentifierName(variableDeclaration.identifier.name)) := \(rhsCode)"
    case .identifier(let identifier) where !identifier.isImplicitPropertyAccess:
      return "\(mangleIdentifierName(identifier.name)) := \(rhsCode)"
    default:
      let lhsCode = render(lhs, asLValue: true)
      return "sstore(\(lhsCode), \(rhsCode))"
    }
  }

  func renderPropertyAccess(lhs: Expression, rhs: Expression, asLValue: Bool) -> String {
    let rhsCode = render(rhs, asLValue: asLValue)

    if case .self(_) = lhs {
      return rhsCode
    }
    
    let lhsCode = render(lhs, asLValue: asLValue)
    return "\(lhsCode).\(rhsCode)"
  }

  func render(_ functionCall: FunctionCall) -> String {
    let args: String = functionCall.arguments.map({ render($0) }).joined(separator: ", ")
    return "\(functionCall.identifier.name)(\(args))"
  }

  func render(_ identifier: Identifier, asLValue: Bool = false) -> String {
    if identifier.isImplicitPropertyAccess {
      let offset = contractStorage.offset(for: identifier.name)
      if asLValue {
        return "\(offset)"
      }
      return "sload(\(offset))"
    }
    return mangleIdentifierName(identifier.name)
  }

  func render(_ variableDeclaration: VariableDeclaration) -> String {
    return "var \(variableDeclaration.identifier)"
  }

  func render(literalToken: Token) -> String {
    guard case .literal(let literal) = literalToken.kind else {
      fatalError("Unexpected token \(literalToken.kind).")
    }

    switch literal {
    case .boolean(let boolean): return boolean == .false ? "0" : "1"
    case .decimal(.real(let num1, let num2)): return "\(num1).\(num2)"
    case .decimal(.integer(let num)): return "\(num)"
    case .string(let string): return "\"\(string)\""
    }
  }

  func render(selfToken: Token) -> String {
    guard case .self = selfToken.kind else {
      fatalError("Unexpected token \(selfToken.kind)")
    }
    return ""
  }

  func render(_ arrayAccess: ArrayAccess, asLValue: Bool = false) -> String {
    let arrayIdentifier = arrayAccess.arrayIdentifier

    let offset = contractStorage.offset(for: arrayIdentifier.name)
    let indexExpressionCode = render(arrayAccess.indexExpression)

    let type = context.type(of: arrayAccess.arrayIdentifier, contractIdentifier: contractIdentifier).rawType
    guard case .arrayType(_, _) = type else { fatalError() }

    if arrayIdentifier.isImplicitPropertyAccess {
      if asLValue {
        return "\(IULIAUtilFunction.storageArrayOffset.rawValue)(\(offset), \(indexExpressionCode), \(type.size))"
      } else {
        return "\(IULIAUtilFunction.storageArrayElementAtIndex.rawValue)(\(offset), \(indexExpressionCode), \(type.size))"
      }
    }

    fatalError()
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
