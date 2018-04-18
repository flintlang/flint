//
//  IULIAFunction.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/28/17.
//

import AST
import Foundation
import CryptoSwift

/// A function in IULIA IR.
struct IULIAFunction {
  static let returnVariableName = "ret"

  var functionDeclaration: FunctionDeclaration
  var typeIdentifier: Identifier

  var capabilityBinding: Identifier?
  var callerCapabilities: [CallerCapability]

  var environment: Environment

  var isContractFunction = false

  init(functionDeclaration: FunctionDeclaration, typeIdentifier: Identifier, capabilityBinding: Identifier? = nil, callerCapabilities: [CallerCapability] = [], environment: Environment) {
    self.functionDeclaration = functionDeclaration
    self.typeIdentifier = typeIdentifier
    self.capabilityBinding = capabilityBinding
    self.callerCapabilities = callerCapabilities
    self.environment = environment

    if !callerCapabilities.isEmpty {
      isContractFunction = true
    }
  }

  var name: String {
    return functionDeclaration.identifier.name
  }

  var parameterNames: [String] {
    return functionDeclaration.explicitParameters.map({ render($0.identifier) })
  }

  /// The function's parameters and caller capability binding, as variable declarations in a `ScopeContext`.
  var scopeContext: ScopeContext {
    var localVariables = functionDeclaration.parametersAsVariableDeclarations
    if let capabilityBinding = capabilityBinding {
      localVariables.append(VariableDeclaration(declarationToken: nil, identifier: capabilityBinding, type: Type(inferredType: .builtInType(.address), identifier: capabilityBinding)))
    }
    return ScopeContext(localVariables: localVariables)
  }

  var parameterCanonicalTypes: [CanonicalType] {
    return functionDeclaration.explicitParameters.map({ CanonicalType(from: $0.type.rawType)! })
  }

  var resultCanonicalType: CanonicalType? {
    return functionDeclaration.resultType.flatMap({ CanonicalType(from: $0.rawType)! })
  }

  func rendered() -> String {
    let doesReturn = functionDeclaration.resultType != nil
    let parametersString = parameterNames.joined(separator: ", ")
    let signature = "\(name)(\(parametersString)) \(doesReturn ? "-> \(IULIAFunction.returnVariableName)" : "")"

    // Dynamically check the caller has appropriate caller capabilities.
    let callerCapabilityChecks = renderCallerCapabilityChecks(callerCapabilities: callerCapabilities)
    let body = renderBody(functionDeclaration.body)


    // Assign a caller capaiblity binding to a local variable.
    let capabilityBindingDeclaration: String
    if let capabilityBinding = capabilityBinding {
      capabilityBindingDeclaration = "let \(IULIAFunction.mangleIdentifierName(capabilityBinding.name)) := caller()\n"
    } else {
      capabilityBindingDeclaration = ""
    }

    // Assign Wei value sent to a @payable function to a local variable.
    let payableValueDeclaration: String
    if let payableValueParameter = functionDeclaration.firstPayableValueParameter {
      payableValueDeclaration = "let \(IULIAFunction.mangleIdentifierName(payableValueParameter.identifier.name)) := callvalue()\n"
    } else {
      payableValueDeclaration = ""
    }

    return """
    function \(signature) {
      \(callerCapabilityChecks.indented(by: 2))\(payableValueDeclaration.indented(by: 2))\(capabilityBindingDeclaration.indented(by: 2))\(body.indented(by: 2))
    }
    """
  }

  func renderBody<S : RandomAccessCollection & RangeReplaceableCollection>(_ statements: S) -> String where S.Element == AST.Statement, S.Index == Int {
    guard !statements.isEmpty else { return "" }
    var statements = statements
    let first = statements.removeFirst()
    let firstCode = render(first)
    let restCode = renderBody(statements)

    if case .ifStatement(let ifStatement) = first, ifStatement.endsWithReturnStatement {
      let defaultCode = """

      default {
        \(restCode.indented(by: 2))
      }
      """
      return firstCode + (restCode.isEmpty ? "" : defaultCode)
    } else {
      return firstCode + (restCode.isEmpty ? "" : "\n" + restCode)
    }
  }

  /// The string representation of this function's signature, used for generating a IULIA interface.
  func mangledSignature() -> String {
    let name = functionDeclaration.identifier.name
    let parametersString = parameterCanonicalTypes.map({ $0.rawValue }).joined(separator: ",")

    return "\(name)(\(parametersString))"
  }

  static func mangleIdentifierName(_ name: String) -> String {
    return "_\(name)"
  }

  /// Render dynamic checks for caller capabilities.
  func renderCallerCapabilityChecks(callerCapabilities: [CallerCapability]) -> String {
    let checks = callerCapabilities.compactMap { callerCapability -> String? in
      guard !callerCapability.isAny else { return nil }

      let type = environment.type(of: callerCapability.identifier.name, enclosingType: typeIdentifier.name)!
      let offset = environment.propertyOffset(for: callerCapability.name, enclosingType: typeIdentifier.name)!
      switch type {
      case .fixedSizeArrayType(_, let size):
        return (0..<size).map { index in
          "_flintCallerCheck := add(_flintCallerCheck, \(IULIARuntimeFunction.isValidCallerCapability.rawValue)(sload(add(\(offset), \(index)))))"
          }.joined(separator: "\n")
      case .arrayType(_):
        return "_flintCallerCheck := add(_flintCallerCheck, \(IULIARuntimeFunction.isCallerCapabilityInArray.rawValue)(\(offset)))"
      default:
        return "_flintCallerCheck := add(_flintCallerCheck, \(IULIARuntimeFunction.isValidCallerCapability.rawValue)(sload(\(offset))))"
      }
    }

    if !checks.isEmpty {
      return """
      let _flintCallerCheck := 0
      \(checks.joined(separator: "\n"))
      if eq(_flintCallerCheck, 0) { revert(0, 0) }
      """ + "\n"
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
    case .inoutExpression(let inoutExpression): return render(inoutExpression.expression, asLValue: true)
    case .binaryExpression(let binaryExpression): return render(binaryExpression, asLValue: asLValue)
    case .bracketedExpression(let expression): return render(expression)
    case .functionCall(let functionCall): return render(functionCall)
    case .identifier(let identifier): return render(identifier, asLValue: asLValue)
    case .variableDeclaration(let variableDeclaration): return render(variableDeclaration)
    case .literal(let literal): return render(literalToken: literal)
    case .self(let `self`): return render(selfToken: self, asLValue: asLValue)
    case .subscriptExpression(let subscriptExpression): return render(subscriptExpression, asLValue: asLValue)
    }
  }

  func render(_ binaryExpression: BinaryExpression, asLValue: Bool) -> String {

    if case .dot = binaryExpression.opToken {
      if case .functionCall(let functionCall) = binaryExpression.rhs {
        return render(functionCall)
      }
      return renderPropertyAccess(lhs: binaryExpression.lhs, rhs: binaryExpression.rhs, asLValue: asLValue)
    }

    let lhs = render(binaryExpression.lhs, asLValue: asLValue)
    let rhs = render(binaryExpression.rhs, asLValue: asLValue)
    
    switch binaryExpression.opToken {
    case .equal: return renderAssignment(lhs: binaryExpression.lhs, rhs: binaryExpression.rhs)
    case .plus: return "add(\(lhs), \(rhs))"
    case .minus: return "sub(\(lhs), \(rhs))"
    case .times: return "mul(\(lhs), \(rhs))"
    case .divide: return "div(\(lhs), \(rhs))"
    case .closeAngledBracket: return "gt(\(lhs), \(rhs))"
    case .openAngledBracket: return "lt(\(lhs), \(rhs))"
    case .doubleEqual: return "eq(\(lhs), \(rhs))"
    case .notEqual: return "iszero(eq(\(lhs), \(rhs)))"
    case .or: return "or(\(lhs), \(rhs))"
    case .and: return "and(\(lhs), \(rhs))"
    default: fatalError()
    }
  }

  func renderAssignment(lhs: Expression, rhs: Expression) -> String {
    let rhsCode = render(rhs)

    switch lhs {
    case .variableDeclaration(let variableDeclaration):
      return "let \(IULIAFunction.mangleIdentifierName(variableDeclaration.identifier.name)) := \(rhsCode)"
    case .identifier(let identifier) where identifier.enclosingType == nil:
      return "\(IULIAFunction.mangleIdentifierName(identifier.name)) := \(rhsCode)"
    default:
      let lhsCode = render(lhs, asLValue: true)
      return "sstore(\(lhsCode), \(rhsCode))"
    }
  }

  func renderPropertyAccess(lhs: Expression, rhs: Expression, asLValue: Bool) -> String {
    let lhsOffset: String

    if case .identifier(let lhsIdentifier) = lhs {
      if let enclosingType = lhs.enclosingType, let offset = environment.propertyOffset(for: lhsIdentifier.name, enclosingType: enclosingType) {
        lhsOffset = "\(offset)"
      } else {
        lhsOffset = "\(environment.propertyOffset(for: lhsIdentifier.name, enclosingType: typeIdentifier.name)!)"
      }
    } else {
      lhsOffset = render(lhs, asLValue: true)
    }


    let lhsType = environment.type(of: lhs, enclosingType: typeIdentifier.name, scopeContext: scopeContext)
    let rhsOffset = propertyOffset(for: rhs, in: lhsType)

    let offset: String
    if !isContractFunction {
      offset = "add(_flintSelf, \(rhsOffset))"
    } else {
      offset = "add(\(lhsOffset), \(rhsOffset))"
    }

    if asLValue {
      return offset
    }
    return "sload(\(offset))"
  }

  func propertyOffset(for expression: Expression, in type: Type.RawType) -> String {
    if case .binaryExpression(let binaryExpression) = expression {
      return renderPropertyAccess(lhs: binaryExpression.lhs, rhs: binaryExpression.rhs, asLValue: true)
    }
    guard case .identifier(let identifier) = expression else { fatalError() }
    guard case .userDefinedType(let structIdentifier) = type else { fatalError() }

    return "\(environment.propertyOffset(for: identifier.name, enclosingType: structIdentifier)!)"
  }

  func render(_ functionCall: FunctionCall) -> String {
    if let eventCall = environment.matchEventCall(functionCall, enclosingType: typeIdentifier.name) {
      let types = eventCall.typeGenericArguments

      var stores = [String]()
      var memoryOffset = 0
      for (i, argument) in functionCall.arguments.enumerated() {
        stores.append("mstore(\(memoryOffset), \(render(argument)))")
        memoryOffset += environment.size(of: types[i]) * 32
      }

      let totalSize = types.reduce(0) { return $0 + environment.size(of: $1) } * 32
      let typeList = eventCall.typeGenericArguments.map { type in
        return "\(CanonicalType(from: type)!.rawValue)"
      }.joined(separator: ",")

      let eventHash = "\(functionCall.identifier.name)(\(typeList))".sha3(.keccak256)
      let log = "log1(0, \(totalSize), 0x\(eventHash))"

      return """
      \(stores.joined(separator: "\n"))
      \(log)
      """
    }

    let args: String = functionCall.arguments.map({ argument in
      let type = environment.type(of: argument, enclosingType: typeIdentifier.name, scopeContext: scopeContext)
      return render(argument, asLValue: environment.isReferenceType(type.name))
    }).joined(separator: ", ")
    return "\(functionCall.identifier.name)(\(args))"
  }

  func render(_ identifier: Identifier, asLValue: Bool = false) -> String {
    if let _ = identifier.enclosingType {
      return renderPropertyAccess(lhs: .self(Token(kind: .self, sourceLocation: identifier.sourceLocation)), rhs: .identifier(identifier), asLValue: asLValue)
    }
    return IULIAFunction.mangleIdentifierName(identifier.name)
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

  func render(selfToken: Token, asLValue: Bool) -> String {
    guard case .self = selfToken.kind else {
      fatalError("Unexpected token \(selfToken.kind)")
    }
    return asLValue ? "0" : ""
  }

  func render(_ subscriptExpression: SubscriptExpression, asLValue: Bool = false) -> String {
    let baseIdentifier = subscriptExpression.baseIdentifier

    let offset = environment.propertyOffset(for: subscriptExpression.baseIdentifier.name, enclosingType: subscriptExpression.baseIdentifier.enclosingType!)!
    let indexExpressionCode = render(subscriptExpression.indexExpression)

    let type = environment.type(of: subscriptExpression.baseIdentifier.name, enclosingType: typeIdentifier.name)!

    guard let _ = baseIdentifier.enclosingType else {
      fatalError("Subscriptable types are only supported for contract properties right now.")
    }

    switch type {
    case .arrayType(let elementType):
      let storageArrayOffset = "\(IULIARuntimeFunction.storageArrayOffset.rawValue)(\(offset), \(indexExpressionCode))"
      if asLValue {
        return storageArrayOffset
      } else {
        guard environment.size(of: elementType) == 1 else {
          fatalError("Loading array elements of size > 1 is not supported yet.")
        }
        return "sload(\(storageArrayOffset))"
      }
    case .fixedSizeArrayType(let elementType, _):
      let typeSize = environment.size(of: type)
      let storageArrayOffset = "\(IULIARuntimeFunction.storageFixedSizeArrayOffset.rawValue)(\(offset), \(indexExpressionCode), \(typeSize))"
      if asLValue {
        return storageArrayOffset
      } else {
        guard environment.size(of: elementType) == 1 else {
          fatalError("Loading array elements of size > 1 is not supported yet.")
        }
        return "sload(\(storageArrayOffset))"
      }
    case .dictionaryType(key: let keyType, value: let valueType):
      guard environment.size(of: keyType) == 1 else {
        fatalError("Dictionary keys of size > 1 are not supported yet.")
      }

      let storageDictionaryOffsetForKey = "\(IULIARuntimeFunction.storageDictionaryOffsetForKey.rawValue)(\(offset), \(indexExpressionCode))"

      if asLValue {
        return "\(storageDictionaryOffsetForKey)"
      } else {
        guard environment.size(of: valueType) == 1 else {
          fatalError("Loading dictionary values of size > 1 is not supported yet.")
        }
        return "sload(\(storageDictionaryOffsetForKey))"
      }
    default: fatalError()
    }
  }

  func render(_ ifStatement: IfStatement) -> String {
    let condition = render(ifStatement.condition)
    let body = ifStatement.body.map { statement in
      render(statement)
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
        return render(statement)
      }.joined(separator: "\n")
      elseCode = """
      default {
        \(body.indented(by: 2))
      }
      """
    }

    return ifCode + "\n" + elseCode
  }

  func render(_ returnStatement: ReturnStatement) -> String {
    guard let expression = returnStatement.expression else {
      return ""
    }

    return "\(IULIAFunction.returnVariableName) := \(render(expression))"
  }
}
