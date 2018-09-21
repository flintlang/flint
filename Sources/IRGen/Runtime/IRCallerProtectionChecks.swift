//
//  IRCallerProtectionChecks.swift
//  IRGen
//
//  Created by Hails, Daniel R on 11/07/2018.
//

import AST

/// Checks whether the caller of a function has appropriate caller protections.
struct IRCallerProtectionChecks {
  static let postfix: String = "CallerCheck"
  static let varName: String = "_flint" + postfix

  var variableName: String
  var callerProtections: [CallerProtection]
  let revert: Bool

  init(callerProtections: [CallerProtection], revert: Bool = true, variableName: String = varName) {
    self.variableName = variableName
    self.callerProtections = callerProtections
    self.revert = revert
  }

  func rendered(enclosingType: RawTypeIdentifier, environment: Environment) -> String {
    let checks = callerProtections.compactMap { callerProtection -> String? in
      guard !callerProtection.isAny else { return nil }

      let type = environment.type(of: callerProtection.identifier.name, enclosingType: enclosingType)
      let offset = environment.propertyOffset(for: callerProtection.name, enclosingType: enclosingType)
      let functionContext = FunctionContext(environment: environment, scopeContext: ScopeContext(), enclosingTypeName: enclosingType, isInStructFunction: false)

      switch type {
      case .functionType(parameters: [], result: .basicType(.address)):
        var identifier = callerProtection.identifier
        let name = Mangler.mangleFunctionName(identifier.name, parameterTypes: [], enclosingType: enclosingType)
        identifier.identifierToken.kind = .identifier(name)
        let functionCall = IRFunctionCall(functionCall: FunctionCall(identifier: identifier, arguments: [], closeBracketToken: .init(kind: .punctuation(.closeBracket), sourceLocation: .DUMMY), isAttempted: false))
        let check = "eq(caller(), \(functionCall.rendered(functionContext: functionContext)))"
        return "\(variableName) := add(\(variableName), \(check))"
      case .functionType(parameters: [.basicType(.address)], result: .basicType(.bool)):
        var identifier = callerProtection.identifier
        let name = Mangler.mangleFunctionName(identifier.name, parameterTypes: [.basicType(.address)], enclosingType: enclosingType)
        identifier.identifierToken.kind = .identifier(name)
        let functionCall = IRFunctionCall(functionCall: FunctionCall(identifier: identifier, arguments: [FunctionArgument(.rawAssembly("caller()", resultType: .basicType(.address)))], closeBracketToken: .init(kind: .punctuation(.closeBracket), sourceLocation: .DUMMY), isAttempted: false))
        let check = "\(functionCall.rendered(functionContext: functionContext))"
        return "\(variableName) := add(\(variableName), \(check))"
      case .fixedSizeArrayType(_, let size):
        return (0..<size).map { index in
          let check = IRRuntimeFunction.isValidCallerProtection(address: "sload(add(\(offset!), \(index)))")
          return "\(variableName) := add(\(variableName), \(check)"
          }.joined(separator: "\n")
      case .arrayType(_):
        let check = IRRuntimeFunction.isCallerProtectionInArray(arrayOffset: offset!)
        return "\(variableName) := add(\(variableName), \(check))"
      case .basicType(.address):
        let check = IRRuntimeFunction.isValidCallerProtection(address: "sload(\(offset!)))")
        return "\(variableName) := add(\(variableName), \(check)"
      case .basicType(_), .stdlibType(_), .rangeType(_), .dictionaryType(_), .userDefinedType(_),
           .inoutType(_), .functionType(_), .any, .errorType:
        return ""
      }




      }
    let revertString = revert ? "if eq(\(variableName), 0) { revert(0, 0) }" : ""
      if !checks.isEmpty {
      return """
       let \(variableName) := 0
       \(checks.joined(separator: "\n"))
       \(revertString)
       """
      }

      return ""
  }
}
