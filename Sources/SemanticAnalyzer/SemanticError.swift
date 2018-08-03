//
//  SemanticError.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 1/4/18.
//

import AST

// MARK: Errors

extension Diagnostic {
  static func invalidRedeclaration(_ identifier: Identifier, originalSource: Identifier) -> Diagnostic {
    let note = Diagnostic(severity: .note, sourceLocation: originalSource.sourceLocation, message: "\(originalSource.name) is declared here")
    return Diagnostic(severity: .error, sourceLocation: identifier.sourceLocation, message: "Invalid redeclaration of '\(identifier.name)'", notes: [note])
  }

  static func invalidCharacter(_ identifier: Identifier, character: Character) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: identifier.sourceLocation, message: "Use of invalid character '\(character)' in '\(identifier.name)'")
  }

  static func invalidAddressLiteral(_ literalToken: Token) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: literalToken.sourceLocation, message: "Address literal should be 42 characters long")
  }

  static func noMatchingFunctionForFunctionCall(_ functionCall: FunctionCall, contextCallerCapabilities: [CallerCapability], stateCapabilities: [TypeState], candidates: [FunctionInformation]) -> Diagnostic {

    let candidateNotes = candidates.map { candidate -> Diagnostic in
      let callerCapabilities = renderGroup(candidate.callerCapabilities)
      let messageTail: String

      if candidate.callerCapabilities.count > 1 {
        messageTail = "one of the caller capabilities in '(\(callerCapabilities))'"
      } else {
        messageTail = "the caller capability '\(callerCapabilities)'"
      }

      return Diagnostic(severity: .note, sourceLocation: candidate.declaration.sourceLocation, message: "Perhaps you meant this function, which requires \(messageTail)")
    }

    let callerPlural = contextCallerCapabilities.count > 1
    let statesPlural = stateCapabilities.count > 1
    return Diagnostic(severity: .error, sourceLocation: functionCall.sourceLocation, message: "Function '\(functionCall.identifier.name)' is not in scope or cannot be called using the \(callerPlural ? "capabilities" : "capability") '\(renderGroup(contextCallerCapabilities))' at \(statesPlural ? "states": "state") '\(renderGroup(stateCapabilities))'", notes: candidateNotes)
  }

  static func contractBehaviorDeclarationNoMatchingContract(_ contractBehaviorDeclaration: ContractBehaviorDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: contractBehaviorDeclaration.sourceLocation, message: "Contract behavior declaration for '\(contractBehaviorDeclaration.contractIdentifier.name)' has no associated contract declaration")
  }

  static func contractBehaviorDeclarationMismatchedStatefulness(_ contractBehaviorDeclaration: ContractBehaviorDeclaration) -> Diagnostic {
    let isContractStateful = contractBehaviorDeclaration.typeStates == []

    return Diagnostic(severity: .error, sourceLocation: contractBehaviorDeclaration.sourceLocation, message: "Contract '\(contractBehaviorDeclaration.contractIdentifier.name)' is \(isContractStateful ? "" : "not ")stateful but behavior declaration is\(!isContractStateful ? "" : " not")")
  }

  static func undeclaredCallerCapability(_ callerCapability: CallerCapability, contractIdentifier: Identifier) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: callerCapability.sourceLocation, message: "Caller capability '\(callerCapability.name)' is undefined in '\(contractIdentifier.name)' or has incompatible type")
  }

  static func useOfMutatingExpressionInNonMutatingFunction(_ expression: Expression, functionDeclaration: FunctionDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: expression.sourceLocation, message: "Use of mutating statement in a nonmutating function")
  }

  static func payableFunctionDoesNotHavePayableValueParameter(_ functionDeclaration: FunctionDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: functionDeclaration.sourceLocation, message: "Function '\(functionDeclaration.identifier.name)' is declared @payable but doesn't have an implicit parameter of a currency type")
  }

  static func payableFunctionHasNonPayableValueParameter(_ functionDeclaration: FunctionDeclaration) -> Diagnostic {
      return Diagnostic(severity: .error, sourceLocation: functionDeclaration.sourceLocation, message: "Payable function '\(functionDeclaration.identifier.name)' has an implicit parameter of non-currency type")
  }

  static func invalidImplicitParameter(_ functionDeclaration: FunctionDeclaration, _ violatingParameter: Identifier) -> Diagnostic {
      return Diagnostic(severity: .error, sourceLocation: functionDeclaration.sourceLocation, message: "Parameter '\(violatingParameter.name)' cannot be marked 'implicit' in function '\(functionDeclaration.identifier.name)'")
  }

  static func useOfDynamicParamaterInFunctionDeclaration(_ functionDeclaration: FunctionDeclaration, dynamicParameters: [Parameter]) -> Diagnostic {
    let notes = dynamicParameters.map { Diagnostic(severity: .note, sourceLocation: $0.sourceLocation, message: "\($0.identifier.name) cannot be used as a parameter") }
    return Diagnostic(severity: .error, sourceLocation: functionDeclaration.sourceLocation, message: "Function '\(functionDeclaration.identifier.name)' cannot have dynamic parameters", notes: notes)
  }

  static func ambiguousPayableValueParameter(_ functionDeclaration: FunctionDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: functionDeclaration.sourceLocation, message: "Ambiguous implicit payable value parameter. Only one parameter can be declared implicit with a currency type")
  }

  static func useOfUndeclaredIdentifier(_ identifier: Identifier) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: identifier.sourceLocation, message: "Use of undeclared identifier '\(identifier.name)'")
  }

  static func useOfUndeclaredType(_ type: Type) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: type.sourceLocation, message: "Use of undeclared type '\(type.name)'")
  }

  static func missingReturnInNonVoidFunction(closeBraceToken: Token, resultType: Type) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: closeBraceToken.sourceLocation, message: "Missing return in function expected to return '\(resultType.name)'")
  }

  static func invalidReturnTypeInFunction(_ functionDeclaration: FunctionDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: functionDeclaration.sourceLocation, message: "Type '\(functionDeclaration.resultType!.name)' not valid as return type in function '\(functionDeclaration.identifier.name)'")
  }

  static func reassignmentToConstant(_ identifier: Identifier, _ declarationSourceLocation: SourceLocation) -> Diagnostic {
    let note = Diagnostic(severity: .note, sourceLocation: declarationSourceLocation, message: "'\(identifier.name)' is declared here")
    return Diagnostic(severity: .error, sourceLocation: identifier.sourceLocation, message: "Cannot reassign to value: '\(identifier.name)' is a 'let' constant", notes: [note])
  }

  static func statePropertyIsNotAssignedAValue(_ variableDeclaration: VariableDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: variableDeclaration.sourceLocation, message: "State property '\(variableDeclaration.identifier.name)' needs to be assigned a value")
  }

  static func statePropertyUsedWithinPropertyInitializer(_ identifier: Identifier) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: identifier.sourceLocation, message: "Cannot use state property '\(identifier.name)' within the initialization of another property")
  }

  static func invalidRangeDeclaration(_ literalExpression: Expression) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: literalExpression.sourceLocation, message: "Cannot create ranges of non-numeric literals")
  }

  static func recursiveStruct(_ structIdentifier: Identifier, _ enclosingType: PropertyInformation) -> Diagnostic {
    let note = Diagnostic(severity: .note, sourceLocation: enclosingType.sourceLocation, message: "State property '\(enclosingType.property.identifier.name)' of type '\(enclosingType.rawType.name)' refers to enclosing type of '\(structIdentifier.name)'")
    return Diagnostic(severity: .error, sourceLocation: structIdentifier.sourceLocation, message: "Declaration of recursive struct '\(structIdentifier.name)'", notes: [note])
  }

  static func returnFromInitializerWithoutInitializingAllProperties(_ initializerDeclaration: InitializerDeclaration, unassignedProperties: [Property]) -> Diagnostic {
    let notes = unassignedProperties.map { property in
      return Diagnostic(severity: .note, sourceLocation: property.sourceLocation, message: "'\(property.identifier.name)' is uninitialized")
    }

    return Diagnostic(severity: .error, sourceLocation: initializerDeclaration.closeBraceToken.sourceLocation, message: "Return from initializer without initializing all properties", notes: notes)
  }

  static func returnFromInitializerWithoutInitializingState(_ initializerDeclaration: InitializerDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: initializerDeclaration.sourceLocation, message: "Return from initializer without initializing state in stateful contract")
  }

  static func contractDoesNotHaveAPublicInitializer(contractIdentifier: Identifier) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: contractIdentifier.sourceLocation, message: "Contract '\(contractIdentifier.name)' needs a public initializer accessible using the capability 'any'")
  }

  static func multiplePublicInitializersDefined(_ invalidAdditionalInitializer: InitializerDeclaration, originalInitializerLocation: SourceLocation) -> Diagnostic {
    let note = Diagnostic(severity: .note, sourceLocation: originalInitializerLocation, message: "A public initializer is already declared here")
    return Diagnostic(severity: .error, sourceLocation: invalidAdditionalInitializer.sourceLocation, message: "A public initializer has already been defined", notes: [note])
  }

  static func contractInitializerNotDeclaredInAnyCallerCapabilityBlock(_ initializerDeclaration: InitializerDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: initializerDeclaration.sourceLocation, message: "Public contract initializer should be callable using caller capability 'any'")
  }

  static func cannotInferHiddenValue(_ identifier: Identifier, _ type: Type) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: identifier.sourceLocation, message: "Cannot infer hidden values in case '\(identifier.name)' for hidden type '\(type.name)'")
  }

  static func invalidHiddenValue(_ enumCase: EnumCase) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: enumCase.hiddenValue!.sourceLocation, message: "Invalid hidden value for enum case '\(enumCase.identifier.name)'")
  }

  static func invalidHiddenType(_ enumDeclaration: EnumDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: enumDeclaration.type.sourceLocation, message: "Invalid hidden type '\(enumDeclaration.type.name)' for enum '\(enumDeclaration.identifier.name)'")
  }

  static func invalidReference(_ identifier: Identifier) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: identifier.sourceLocation, message: "Cannot reference enum '\(identifier.name)' alone")
  }

  static func multipleReturns(_ statement: Statement) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: statement.sourceLocation, message: "Early returns are not supported yet")
  }

  static func renderGroup(_ capabilities: [CallerCapability]) -> String {
    return "\(capabilities.map({ $0.name }).joined(separator: ", "))"
  }

  static func renderGroup(_ states: [TypeState]) -> String {
    return "\(states.map({ $0.name }).joined(separator: ", "))"
  }
}

// MARK: Warnings

extension Diagnostic {
  static func codeAfterReturn(_ statement: Statement) -> Diagnostic {
    return Diagnostic(severity: .warning, sourceLocation: statement.sourceLocation, message: "Code after return/become will never be executed")
  }

  static func multipleBecomes(_ statement: Statement) -> Diagnostic {
    return Diagnostic(severity: .warning, sourceLocation: statement.sourceLocation, message: "Only final become will change state")
  }

  static func emptyRange(_ rangeExpression: AST.RangeExpression) -> Diagnostic {
    return Diagnostic(severity: .warning, sourceLocation: rangeExpression.sourceLocation, message: "Range is empty therefore content will be skipped")
  }

  static func functionCanBeDeclaredNonMutating(_ mutatingToken: Token) -> Diagnostic {
    return Diagnostic(severity: .warning, sourceLocation: mutatingToken.sourceLocation, message: "Function does not have to be declared mutating: none of its statements are mutating")
  }

  static func contractNotDeclaredInModule() -> Diagnostic {
    return Diagnostic(severity: .warning, sourceLocation: nil, message: "No contract declaration in top level module")
  }
}
