//
//  SemanticError.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 1/4/18.
//

import AST
import Source
import Diagnostic
import Lexer

// MARK: Errors

extension Diagnostic {
  static func invalidRedeclaration(_ identifier: Identifier, originalSource: Identifier) -> Diagnostic {
    let note = Diagnostic(severity: .note, sourceLocation: originalSource.sourceLocation,
                          message: "\(originalSource.name) is declared here")
    return Diagnostic(severity: .error, sourceLocation: identifier.sourceLocation,
                      message: "Invalid redeclaration of '\(identifier.name)'", notes: [note])
  }

  static func invalidCharacter(_ identifier: Identifier, character: Character) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: identifier.sourceLocation,
                      message: "Use of invalid character '\(character)' in '\(identifier.name)'")
  }

  static func invalidAddressLiteral(_ literalToken: Token) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: literalToken.sourceLocation,
                      message: "Address literal should be 42 characters long")
  }

  static func noTryForFunctionCall(_ functionCall: FunctionCall,
                                   contextCallerProtections: [CallerProtection],
                                   stateProtections: [TypeState],
                                   candidates: [CallableInformation]) -> Diagnostic {
    let candidateNotes = candidates.map { candidate -> Diagnostic in
      guard case .functionInformation(let functionCandidate) = candidate else {
        fatalError("Non-function CallableInformation where function expected")
      }
      let callerProtections = renderGroup(functionCandidate.callerProtections)
      let messageTail: String

      if functionCandidate.callerProtections.count == 0 {
        messageTail = ""
      } else if functionCandidate.callerProtections.count > 1 {
        messageTail = ", which requires one of the caller protections in '(\(callerProtections))'"
      } else {
        messageTail = ", which requires the caller protection '\(callerProtections)'"
      }

      return Diagnostic(severity: .note, sourceLocation: functionCandidate.declaration.sourceLocation,
                        message: "Perhaps you meant this function\(messageTail)")
    }

    let callerPlural = contextCallerProtections.count > 1
    let statesPlural = stateProtections.count > 1
    let statesSpecified = " at \(statesPlural ? "states": "state") '\(renderGroup(stateProtections))'"
    return Diagnostic(severity: .error, sourceLocation: functionCall.sourceLocation,
                      // swiftlint:disable line_length
                      message: "Function '\(functionCall.identifier.name)' cannot be called using the \(callerPlural ? "protections" : "protection") '\(renderGroup(contextCallerProtections))'\(stateProtections.isEmpty ? "" : statesSpecified)", notes: candidateNotes)
                      // swiftlint:enable line_length
  }

  static func noMatchingFunctionForFunctionCall(_ functionCall: FunctionCall,
                                                candidates: [CallableInformation]) -> Diagnostic {
    let candidateNotes = candidates.map { callablecandidate -> Diagnostic in
      switch callablecandidate {
      case .functionInformation(let candidate):
        let callerProtections = renderGroup(candidate.callerProtections)
        let messageTail: String

        if candidate.callerProtections.count == 0 {
          messageTail = ""
        } else if candidate.callerProtections.count > 1 {
          messageTail = ", which requires one of the caller protections in '(\(callerProtections))'"
        } else {
          messageTail = ", which requires the caller protection '\(callerProtections)'"
        }

        return Diagnostic(severity: .note, sourceLocation: candidate.declaration.sourceLocation,
                          message: "Perhaps you meant this function\(messageTail)")
      case .specialInformation(let candidate):
        if candidate.declaration.isInit {
          return Diagnostic(severity: .note, sourceLocation: candidate.declaration.sourceLocation,
                            message: "Perhaps you meant the initializer for this struct")
        } else {
          // Is fallback
          return Diagnostic(severity: .note, sourceLocation: candidate.declaration.sourceLocation,
                            message: "Perhaps you meant this fallback function")
        }
      }
    }

    return Diagnostic(severity: .error, sourceLocation: functionCall.sourceLocation,
                      message: "Function '\(functionCall.identifier.name)' is not in scope", notes: candidateNotes)
  }

  static func partialMatchingEvents(_ functionCall: FunctionCall, candidates: [EventInformation]) -> Diagnostic {
    let candidateNotes = candidates.map { candidate -> Diagnostic in
      let variableDeclarations = candidate.declaration.variableDeclarations.map {
        "\($0.identifier.name): \($0.type)"
      }.joined(separator: ", ")

      let identName = candidate.declaration.identifier.name
      return Diagnostic(severity: .note,
                        sourceLocation: candidate.declaration.sourceLocation,
                        message: "Perhaps you meant this event '\(identName)(\(variableDeclarations))'")
    }

    return Diagnostic(severity: .error,
                      sourceLocation: functionCall.sourceLocation,
                      message: "Event '\(functionCall.identifier.name)' cannot be called using the given parameters",
                      notes: candidateNotes)
  }

  static func noMatchingEvents(_ functionCall: FunctionCall) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: functionCall.identifier.sourceLocation,
                      message: "Event '\(functionCall.identifier.name)' is not in scope")
  }

  static func useOfSelfOutsideTrait(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation,
                      message: "Use of Self is only allowed in traits")
  }

  static func noReceiverForStructInitializer(_ functionCall: FunctionCall) -> Diagnostic {
    return Diagnostic(
      severity: .error, sourceLocation: functionCall.sourceLocation,
      message: "Cannot call struct initializer '\(functionCall.identifier.name)' without receiver assignment")
  }

  static func contractBehaviorDeclarationNoMatchingContract(
    _ contractBehaviorDeclaration: ContractBehaviorDeclaration) -> Diagnostic {
    let identName = contractBehaviorDeclaration.contractIdentifier.name
    return Diagnostic(
      severity: .error, sourceLocation: contractBehaviorDeclaration.sourceLocation,
      message: "Contract behavior declaration for '\(identName)' has no associated contract declaration")
  }

  static func contractBehaviorDeclarationMismatchedStatefulness(
    _ contractBehaviorDeclaration: ContractBehaviorDeclaration) -> Diagnostic {
    let isContractStateful = contractBehaviorDeclaration.states == []

    let identName = contractBehaviorDeclaration.contractIdentifier.name

    let message: String
    if isContractStateful {
      message = "Contract '\(identName)' is stateful but behavior declaration is not"
    } else {
      message = "Contract '\(identName)' is not stateful but behavior declaration is"
    }

    return Diagnostic(severity: .error, sourceLocation: contractBehaviorDeclaration.sourceLocation, message: message)
  }

  static func signatureInContract(at sourceLocation: SourceLocation) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: sourceLocation,
                      message: "Cannot use signatures in contracts, only in traits")
  }

  static func invalidStructTraitMember(_ member: TraitMember) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: member.sourceLocation,
                      message: "Member invalid in struct trait context")
  }

  static func invalidContractTraitMember(_ member: TraitMember) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: member.sourceLocation,
                      message: "Member invalid in contract trait context")
  }

  static func invalidExternalTraitMember(_ member: TraitMember) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: member.sourceLocation,
                      message: "Member invalid in external trait context")
  }

  static func undeclaredCallerProtection(_ callerProtection: CallerProtection,
                                         contractIdentifier: Identifier) -> Diagnostic {
    return Diagnostic(
      severity: .error, sourceLocation: callerProtection.sourceLocation,
      message: "Caller protection '\(callerProtection.name)' is undefined " +
               "in '\(contractIdentifier.name)' or has incompatible type")
  }

  static func useOfMutatingExpressionInNonMutatingFunction(_ expression: Expression,
                                                           functionDeclaration: FunctionDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: expression.sourceLocation,
                      message: "Use of mutating statement in a nonmutating function")
  }

  static func payableFunctionDoesNotHavePayableValueParameter(
    _ functionDeclaration: FunctionDeclaration) -> Diagnostic {
    return Diagnostic(
      severity: .error, sourceLocation: functionDeclaration.sourceLocation,
      message: "Function '\(functionDeclaration.identifier.name)' is declared @payable " +
               "but doesn't have an implicit parameter of a currency type")
  }

  static func payableFunctionHasNonPayableValueParameter(_ functionDeclaration: FunctionDeclaration) -> Diagnostic {
      return Diagnostic(
        severity: .error, sourceLocation: functionDeclaration.sourceLocation,
        message: "Payable function '\(functionDeclaration.identifier.name)' " +
                 "has an implicit parameter of non-currency type")
  }

  static func invalidImplicitParameter(_ functionDeclaration: FunctionDeclaration,
                                       _ violatingParameter: Identifier) -> Diagnostic {
      return Diagnostic(severity: .error, sourceLocation: functionDeclaration.sourceLocation,
                        message: "Parameter '\(violatingParameter.name)' cannot be marked " +
                                 "'implicit' in function '\(functionDeclaration.identifier.name)'")
  }

  static func useOfDynamicParamaterInFunctionDeclaration(_ functionDeclaration: FunctionDeclaration,
                                                         dynamicParameters: [Parameter]) -> Diagnostic {
    let notes = dynamicParameters.map {
      Diagnostic(severity: .note, sourceLocation: $0.sourceLocation,
                 message: "\($0.identifier.name) cannot be used as a parameter")
    }
    return Diagnostic(severity: .error, sourceLocation: functionDeclaration.sourceLocation,
                      message: "Function '\(functionDeclaration.identifier.name)' cannot have dynamic parameters",
                      notes: notes)
  }

  static func notImplementedFunctions(_ functions: [FunctionInformation], in decl: ContractDeclaration) -> Diagnostic {
    return notImplementedFunctions(functions, in: "Contract \(decl.identifier.name)", at: decl.sourceLocation)
  }

  static func notImplementedFunctions(_ functions: [FunctionInformation], in decl: StructDeclaration) -> Diagnostic {
    return notImplementedFunctions(functions, in: "Struct \(decl.identifier.name)", at: decl.sourceLocation)
  }

  static func notImplementedFunctions(_ functions: [FunctionInformation], in string: String,
                                      at source: SourceLocation) -> Diagnostic {
    let notes = functions.map { function -> Diagnostic in
      if function.isSignature {
        return Diagnostic(severity: .note, sourceLocation: function.declaration.sourceLocation,
                          message: "Function signature has not been implemented")
      }
      return Diagnostic(severity: .note, sourceLocation: function.declaration.sourceLocation,
                        message: "Is this meant to implement the trait signature?")
    }
    return Diagnostic(severity: .error, sourceLocation: source,
                      message: "\(string) doesn't conform to traits as it doesn't implement the declared functions",
                      notes: notes)
  }

  static func notImplementedInitialiser(_ intialisers: [SpecialInformation],
                                        in string: String, at source: SourceLocation) -> Diagnostic {
    let notes = intialisers.map {
      Diagnostic(severity: .note, sourceLocation: $0.declaration.sourceLocation,
                 message: "Initialiser has not been implemented")
    }

    return Diagnostic(severity: .error, sourceLocation: source,
                      message: "\(string) doesn't conform to traits as it doesn't implement the declared initialiser",
                      notes: notes)
  }

  static func notImplementedInitialiser(_ intialisers: [SpecialInformation],
                                        in decl: ContractDeclaration) -> Diagnostic {
    return notImplementedInitialiser(intialisers, in: "Contract", at: decl.sourceLocation)
  }

  static func notImplementedInitialiser(_ intialisers: [SpecialInformation],
                                        in decl: StructDeclaration) -> Diagnostic {
    return notImplementedInitialiser(intialisers, in: "Struct", at: decl.sourceLocation)
  }

  static func ambiguousPayableValueParameter(_ functionDeclaration: FunctionDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: functionDeclaration.sourceLocation,
                      message: "Ambiguous implicit payable value parameter." +
                               " Only one parameter can be declared implicit with a currency type")
  }

  static func useOfUndeclaredIdentifier(_ identifier: Identifier) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: identifier.sourceLocation,
                      message: "Use of undeclared identifier '\(identifier.name)'")
  }

  static func useOfUndeclaredType(_ type: Type) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: type.sourceLocation,
                      message: "Use of undeclared type '\(type.name)'")
  }

  static func missingReturnInNonVoidFunction(closeBraceToken: Token, resultType: Type) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: closeBraceToken.sourceLocation,
                      message: "Missing return in function expected to return '\(resultType.name)'")
  }

  static func invalidReturnTypeInFunction(_ functionDeclaration: FunctionDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: functionDeclaration.sourceLocation,
                      message: "Type '\(functionDeclaration.signature.resultType!.name)' not valid as " +
                               "return type in function '\(functionDeclaration.identifier.name)'")
  }

  static func reassignmentToConstant(_ identifier: Identifier,
                                     _ declarationSourceLocation: SourceLocation) -> Diagnostic {
    let note = Diagnostic(severity: .note, sourceLocation: declarationSourceLocation,
                          message: "'\(identifier.name)' is declared here")
    return Diagnostic(severity: .error, sourceLocation: identifier.sourceLocation,
                      message: "Cannot reassign to value: '\(identifier.name)' is a 'let' constant",
                      notes: [note])
  }

  static func statePropertyIsNotAssignedAValue(_ variableDeclaration: VariableDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: variableDeclaration.sourceLocation,
                      message: "State property '\(variableDeclaration.identifier.name)' needs to be assigned a value")
  }

  static func statePropertyUsedWithinPropertyInitializer(_ identifier: Identifier) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: identifier.sourceLocation,
                      message: "Cannot use state property '\(identifier.name)' within the " +
                               "initialization of another property")
  }

  static func invalidRangeDeclaration(_ literalExpression: Expression) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: literalExpression.sourceLocation,
                      message: "Cannot create ranges of non-numeric literals")
  }

  static func recursiveStruct(_ structIdentifier: Identifier, _ enclosingType: PropertyInformation) -> Diagnostic {
    let identName = enclosingType.property.identifier.name
    let note = Diagnostic(severity: .note, sourceLocation: enclosingType.sourceLocation,
                          message: "State property '\(identName)' of type '\(enclosingType.rawType.name)' refers to " +
                                   "enclosing type of '\(structIdentifier.name)'")
    return Diagnostic(severity: .error, sourceLocation: structIdentifier.sourceLocation,
                      message: "Declaration of recursive struct '\(structIdentifier.name)'",
                      notes: [note])
  }

  // INITALISER ERRORS //

  static func returnFromInitializerWithoutInitializingAllProperties(_ initializerDeclaration: SpecialDeclaration,
                                                                    unassignedProperties: [Property]) -> Diagnostic {
    let notes = unassignedProperties.map { property in
      return Diagnostic(severity: .note, sourceLocation: property.sourceLocation,
                        message: "'\(property.identifier.name)' is uninitialized")
    }

    return Diagnostic(severity: .error, sourceLocation: initializerDeclaration.closeBraceToken.sourceLocation,
                      message: "Return from initializer without initializing all properties",
                      notes: notes)
  }

  static func returnFromInitializerWithoutInitializingState(
    _ initializerDeclaration: SpecialDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: initializerDeclaration.sourceLocation,
                      message: "Return from initializer without initializing state in stateful contract")
  }

  static func contractDoesNotHaveAPublicInitializer(contractIdentifier: Identifier) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: contractIdentifier.sourceLocation,
                      message: "Contract '\(contractIdentifier.name)' needs a public initializer accessible " +
                               "using the protection 'any'")
  }

  static func repeatedConformance(contractIdentifier: Identifier) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: contractIdentifier.sourceLocation,
                      message: "Contract '\(contractIdentifier.name)' has repeated conformances")
  }

  static func repeatedConformance(structIdentifier: Identifier) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: structIdentifier.sourceLocation,
                      message: "Struct '\(structIdentifier.name)' has repeated conformances")
  }

  static func traitsAreIncompatible(_ contractDeclaration: ContractDeclaration,
                                    _ functions: [FunctionInformation]) -> Diagnostic {
     return traitsAreIncompatible(in: "Contract '\(contractDeclaration.identifier.name)'",
      with: functions,
      at: contractDeclaration.sourceLocation)
  }

  static func traitsAreIncompatible(_ structDeclaration: StructDeclaration,
                                    _ functions: [FunctionInformation]) -> Diagnostic {
    return traitsAreIncompatible(in: "Struct '\(structDeclaration.identifier.name)'",
      with: functions,
      at: structDeclaration.sourceLocation)
  }

  static func traitsAreIncompatible(in type: String,
                                    with functions: [FunctionInformation],
                                    at source: SourceLocation) -> Diagnostic {
    let notes = functions.map { function in
      return Diagnostic(severity: .note, sourceLocation: function.declaration.sourceLocation,
                        message: "Function with the name '\(function.declaration.name)' has been declared here")
    }
    return Diagnostic(severity: .error, sourceLocation: source,
                      message: "\(type) conforms to traits using the same function name",
                      notes: notes)
  }

  static func contractUsesUndeclaredTraits(_ trait: Conformance, in type: Identifier) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: trait.sourceLocation,
                      message: "Contract '\(type.name)' conforms to undeclared trait '\(trait.identifier.name)'")
  }

  static func multiplePublicInitializersDefined(_ invalidAdditionalInitializer: SpecialDeclaration,
                                                originalInitializerLocation: SourceLocation) -> Diagnostic {
    let note = Diagnostic(severity: .note, sourceLocation: originalInitializerLocation,
                          message: "A public initializer is already declared here")
    return Diagnostic(severity: .error, sourceLocation: invalidAdditionalInitializer.sourceLocation,
                      message: "A public initializer has already been defined",
                      notes: [note])
  }

  static func contractInitializerNotDeclaredInAnyCallerProtectionBlock(
    _ initializerDeclaration: SpecialDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: initializerDeclaration.sourceLocation,
                      message: "Public contract initializer should be callable using caller protection 'any'")
  }

  // FALLBACK ERRORS //

  static func multiplePublicFallbacksDefined(_ invalidAdditionalFallback: SpecialDeclaration,
                                             originalFallbackLocation: SourceLocation) -> Diagnostic {
    let note = Diagnostic(severity: .note, sourceLocation: originalFallbackLocation,
                          message: "A public fallback is already declared here")
    return Diagnostic(severity: .error, sourceLocation: invalidAdditionalFallback.sourceLocation,
                      message: "A public fallback has already been defined",
                      notes: [note])
  }

  static func contractFallbackNotDeclaredInAnyCallerProtectionBlock(
    _ invalidFallback: SpecialDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: invalidFallback.sourceLocation,
                      message: "Public contract fallback should be callable using caller protection 'any'")
  }

  static func fallbackDeclaredWithArguments(_ invalidFallback: SpecialDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: invalidFallback.sourceLocation,
                      message: "Contract fallback shouldn't have any arguments")
  }

  static func cannotInferHiddenValue(_ identifier: Identifier, _ type: Type) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: identifier.sourceLocation,
                      message: "Cannot infer hidden values in case '\(identifier.name)' for hidden type '\(type.name)'")
  }

  static func invalidHiddenValue(_ enumCase: EnumMember) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: enumCase.hiddenValue!.sourceLocation,
                      message: "Invalid hidden value for enum case '\(enumCase.identifier.name)'")
  }

  static func invalidHiddenType(_ enumDeclaration: EnumDeclaration) -> Diagnostic {
    let identName = enumDeclaration.identifier.name
    return Diagnostic(severity: .error, sourceLocation: enumDeclaration.type.sourceLocation,
                      message: "Invalid hidden type '\(enumDeclaration.type.name)' for enum '\(identName)'")
  }

  static func invalidReference(_ identifier: Identifier) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: identifier.sourceLocation,
                      message: "Cannot reference enum '\(identifier.name)' alone")
  }

  static func multipleReturns(_ statement: ReturnStatement) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: statement.sourceLocation,
                      message: "Early returns are not supported yet")
  }

  static func becomeBeforeReturn(_ statement: BecomeStatement) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: statement.sourceLocation,
                      message: "Cannot become before a return")
  }

  static func mutatingConstant(_ variableDeclaration: VariableDeclaration) -> Diagnostic {
    let identName = variableDeclaration.identifier.name
    return Diagnostic(severity: .error, sourceLocation: variableDeclaration.sourceLocation,
                      message: "The variable '\(identName)' is both declared constant and mutating")
  }

  static func publicLet(_ variableDeclaration: VariableDeclaration) -> Diagnostic {
    let identName = variableDeclaration.identifier.name
    return Diagnostic(severity: .error, sourceLocation: variableDeclaration.sourceLocation,
                      message: "The variable '\(identName)' is declared public " +
                               "(and a setter will be synthesised) but let variables cannot be set")
  }

  static func publicAndVisible(_ variableDeclaration: VariableDeclaration) -> Diagnostic {
    let identName = variableDeclaration.identifier.name
    return Diagnostic(severity: .error, sourceLocation: variableDeclaration.sourceLocation,
                      message: "Cannot declare variable '\(identName)' both public and visible")
  }

  static func invalidExternalCallHyperParameter(_ identifier: Identifier) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: identifier.sourceLocation,
                      message: "'\(identifier.name)' is not a valid external call hyper-parameter")
  }

  static func duplicateExternalCallHyperParameter(_ identifier: Identifier) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: identifier.sourceLocation,
                      message: "'\(identifier.name)' hyper-parameter was already specified")
  }

  static func unlabeledExternalCallHyperParameter(_ externalCall: ExternalCall) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: externalCall.sourceLocation,
                      message: "External call hyper-parameter was not labeled")
  }

  static func renderGroup(_ protections: [CallerProtection]) -> String {
    return "\(protections.map({ $0.name }).joined(separator: ", "))"
  }

  static func renderGroup(_ states: [TypeState]) -> String {
    return "\(states.map({ $0.name }).joined(separator: ", "))"
  }
}

// MARK: Warnings

extension Diagnostic {
  static func codeAfterReturn(_ statement: Statement) -> Diagnostic {
    return Diagnostic(severity: .warning, sourceLocation: statement.sourceLocation,
                      message: "Code after return/become will never be executed")
  }

  static func multipleBecomes(_ statement: BecomeStatement) -> Diagnostic {
    return Diagnostic(severity: .warning, sourceLocation: statement.sourceLocation,
                      message: "Only final become will change state")
  }

  static func emptyRange(_ rangeExpression: AST.RangeExpression) -> Diagnostic {
    return Diagnostic(severity: .warning, sourceLocation: rangeExpression.sourceLocation,
                      message: "Range is empty therefore content will be skipped")
  }

  static func functionCanBeDeclaredNonMutating(_ mutatingToken: Token) -> Diagnostic {
    return Diagnostic(severity: .warning, sourceLocation: mutatingToken.sourceLocation,
                      message: "Function does not have to be declared mutating: none of its statements are mutating")
  }

  static func contractNotDeclaredInModule() -> Diagnostic {
    return Diagnostic(severity: .warning, sourceLocation: nil, message: "No contract declaration in top level module")
  }

  static func contractOnlyHasPrivateFallbacks(contractIdentifier: Identifier,
                                              _ privateFallbacks: [SpecialDeclaration]) -> Diagnostic {
    var notes = [Diagnostic]()
    for fallback in privateFallbacks {
      notes.append(Diagnostic(severity: .note, sourceLocation: fallback.sourceLocation,
                              message: "A fallback is declared here"))
    }
    let reference = privateFallbacks.count == 1 ? "a private fallback" : "private fallbacks"
    let identName = contractIdentifier.name
    return Diagnostic(severity: .warning, sourceLocation: contractIdentifier.sourceLocation,
                      message: "Contract '\(identName)' doesn't have a public fallback but does have \(reference)",
                      notes: notes)
  }

  static func fallbackShouldBeSimple(_ complex: SpecialDeclaration, complexStatements: [Statement]) -> Diagnostic {
    var notes = [Diagnostic]()
    complexStatements.forEach {
      notes.append(
        Diagnostic(severity: .note, sourceLocation: $0.sourceLocation,
                   message: "This statement was flagged as 'complex'"))
    }

    return Diagnostic(severity: .warning, sourceLocation: complex.sourceLocation,
                      message: "This fallback is likely to use over 2 300 gas which is the limit " +
                               "for calls sending ETH directly",
                      notes: notes)
  }

  static func nonVoidAttemptCall(_ attempt: AttemptExpression) -> Diagnostic {
    return Diagnostic(severity: .warning, sourceLocation: attempt.sourceLocation,
                      message: "Calling a function returning a non-Void value with try? is not supported yet")
  }

  static func mutatingVariable(_ variableDeclaration: VariableDeclaration) -> Diagnostic {
    return Diagnostic(severity: .warning, sourceLocation: variableDeclaration.sourceLocation,
                      message: "Variables are already implicitly mutating")
  }

  static func defaultArgumentsNotAtEnd(_ functionDeclaration: FunctionDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: functionDeclaration.sourceLocation,
        message: "Default parameters should be the last ones to be declared")
  }

  static func duplicateParameterDeclarations(_ functionDeclaration: FunctionDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: functionDeclaration.sourceLocation,
      message: "Duplicate parameter declarations in function declaration")
  }

  static func defaultArgumentsNotAtEnd(_ eventDeclaration: EventDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: eventDeclaration.sourceLocation,
      message: "Default parameters should be the last ones to be declared")
  }

  static func duplicateParameterDeclarations(_ eventDeclaration: EventDeclaration) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: eventDeclaration.sourceLocation,
      message: "Duplicate parameter declarations in event declaration")
  }

  static func unlabeledFunctionCallArguments(_ functionCall: FunctionCall, isEventCall: Bool) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: functionCall.sourceLocation,
      message: "All arguments of " + (isEventCall ? "an event" : "a function") + " call should be labeled")
  }

  static func invalidConditionTypeInIfStatement(_ ifStatement: IfStatement) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: ifStatement.condition.sourceLocation,
      message: "Condition has invalid type: must be Bool or a valid let statement")
  }

  static func valueParameterForUnpayableFunction(_ externalCall: ExternalCall) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: externalCall.sourceLocation,
      message: "Attempting to call a non-payable function with a 'value' hyper-parameter")
  }

  static func missingValueParameterForPayableFunction(_ externalCall: ExternalCall) -> Diagnostic {
    return Diagnostic(severity: .error, sourceLocation: externalCall.sourceLocation,
      message: "Attempting to call a payable function without specifying a 'value' hyper-parameter")
  }

  static func flintTypeUsedInExternalTrait(_ type: Type, at location: SourceLocation) -> Diagnostic {
    var notes: [Diagnostic] = []
    if case .basicType(let basicType) = type.rawType,
      let solidityParallel = basicType.solidityParallel {
      notes.append(Diagnostic(severity: .note, sourceLocation: location,
                              message: "Perhaps you meant to use '\(solidityParallel)'"))
    }

    return Diagnostic(severity: .error, sourceLocation: location,
                      // swiftlint:disable line_length
                      message: "Only Solidity types may be used in external traits. '\(type.name)' is a Flint type", notes: notes)
                      // swiftlint:enable line_length
  }

  static func solidityTypeUsedOutsideExternalTrait(_ type: Type, at location: SourceLocation) -> Diagnostic {
    var notes: [Diagnostic] = []
    if case .solidityType(let solidityType) = type.rawType,
      let basicParallel = solidityType.basicParallel {
      notes.append(Diagnostic(severity: .note, sourceLocation: location,
                              message: "Perhaps you meant to use '\(basicParallel)'"))
    }

    return Diagnostic(severity: .error, sourceLocation: location,
                      // swiftlint:disable line_length
                      message: "Solidity types may not be used outside of external traits. '\(type.name)' is a Solidity type", notes: notes)
                      // swiftlint:enable line_length
  }
}
