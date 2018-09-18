//
//  SemanticAnalyzer+Declarations.swift
//  SemanticAnalyzer
//
//  Created by Hails, Daniel J R on 21/08/2018.
//

import AST
import Diagnostic

extension SemanticAnalyzer {

  // MARK: Contract
  public func process(contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    var diagnostics = [Diagnostic]()
    let environment = passContext.environment!
    if let conflict = environment.conflictingTypeDeclaration(for: contractDeclaration.identifier) {
      diagnostics.append(.invalidRedeclaration(contractDeclaration.identifier, originalSource: conflict))
    }

    if environment.publicInitializer(forContract: contractDeclaration.identifier.name) == nil {
      diagnostics.append(.contractDoesNotHaveAPublicInitializer(contractIdentifier: contractDeclaration.identifier))
    }
    return ASTPassResult(element: contractDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  // MARK: Contract Behaviour
  public func process(contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    var diagnostics = [Diagnostic]()

    let environment = passContext.environment!

    if !environment.isContractDeclared(contractBehaviorDeclaration.contractIdentifier.name), contractBehaviorDeclaration.contractIdentifier.name != "self" {
      // The contract behavior declaration could not be associated with any contract declaration.
      diagnostics.append(.contractBehaviorDeclarationNoMatchingContract(contractBehaviorDeclaration))
    } else if environment.isStateful(contractBehaviorDeclaration.contractIdentifier.name) != (contractBehaviorDeclaration.states != []) {
      // The statefullness of the contract declaration and contract behavior declaration do not match.
      diagnostics.append(.contractBehaviorDeclarationMismatchedStatefulness(contractBehaviorDeclaration))
    }

    // Create a context containing the contract the methods are defined for, and the caller capabilities the functions
    // within it are scoped by.
    let declarationContext = ContractBehaviorDeclarationContext(contractIdentifier: contractBehaviorDeclaration.contractIdentifier, typeStates: contractBehaviorDeclaration.states, callerCapabilities: contractBehaviorDeclaration.callerCapabilities)

    let passContext = passContext.withUpdates { $0.contractBehaviorDeclarationContext = declarationContext }

    return ASTPassResult(element: contractBehaviorDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  // MARK: Events
  public func process(eventDeclaration: EventDeclaration, passContext: ASTPassContext) -> ASTPassResult<EventDeclaration> {
    var diagnostics = [Diagnostic]()
    let enclosingType = passContext.enclosingTypeIdentifier!.name

    if let conflict = passContext.environment!.conflictingEventDeclaration(for: eventDeclaration.identifier, in: enclosingType) {
      diagnostics.append(.invalidRedeclaration(eventDeclaration.identifier, originalSource: conflict))
    }
    return ASTPassResult(element: eventDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  // MARK: Struct
  public func process(structDeclaration: StructDeclaration, passContext: ASTPassContext) -> ASTPassResult<StructDeclaration> {
    var diagnostics = [Diagnostic]()
    if let conflict = passContext.environment!.conflictingTypeDeclaration(for: structDeclaration.identifier) {
      diagnostics.append(.invalidRedeclaration(structDeclaration.identifier, originalSource: conflict))
    }
    // Detect Recursive types
    let structName = structDeclaration.identifier.name

    if let conflict = passContext.environment!.selfReferentialProperty(in: structName, enclosingType: structName) {
      diagnostics.append(.recursiveStruct(structDeclaration.identifier, conflict))
    }

    return ASTPassResult(element: structDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  // MARK: Enum
  public func process(enumDeclaration: EnumDeclaration, passContext: ASTPassContext) -> ASTPassResult<EnumDeclaration> {
    var diagnostics = [Diagnostic]()

    if let conflict = passContext.environment!.conflictingTypeDeclaration(for: enumDeclaration.identifier) {
      diagnostics.append(.invalidRedeclaration(enumDeclaration.identifier, originalSource: conflict))
    }

    if case .basicType(_) = enumDeclaration.type.rawType {
      // Basic types are supported as hidden types
    } else {
      diagnostics.append(.invalidHiddenType(enumDeclaration))
    }
    return ASTPassResult(element: enumDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(enumCase: EnumMember, passContext: ASTPassContext) -> ASTPassResult<EnumMember> {
    var diagnostics = [Diagnostic]()
    let environment = passContext.environment!

    if let conflict = environment.conflictingPropertyDeclaration(for: enumCase.identifier, in: enumCase.type.rawType.name) {
      diagnostics.append(.invalidRedeclaration(enumCase.identifier, originalSource: conflict))
    }

    if enumCase.hiddenValue == nil {
      diagnostics.append(.cannotInferHiddenValue(enumCase.identifier, enumCase.hiddenType))
    }
    else if case .literal(_)? = enumCase.hiddenValue {} else {
      diagnostics.append(.invalidHiddenValue(enumCase))
    }

    return ASTPassResult(element: enumCase, diagnostics: diagnostics, passContext: passContext)
  }

  // MARK: Trait
  public func process(traitDeclaration: TraitDeclaration, passContext: ASTPassContext) -> ASTPassResult<TraitDeclaration> {
    var diagnostics = [Diagnostic]()
    let environment = passContext.environment!

    if let conflict = environment.conflictingTypeDeclaration(for: traitDeclaration.identifier) {
      diagnostics.append(.invalidRedeclaration(traitDeclaration.identifier, originalSource: conflict))
    }
    traitDeclaration.members.forEach { member in
      if traitDeclaration.traitKind.kind == .struct, isContractTraitMember(member: member) {
        diagnostics.append(.contractTraitMemberInStructTrait(member))
      }
      if traitDeclaration.traitKind.kind == .contract, isStructTraitMember(member: member) {
        diagnostics.append(.structTraitMemberInContractTrait(member))
      }
    }

    return ASTPassResult(element: traitDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  func isContractTraitMember(member: TraitMember) -> Bool {
    switch member {
    case .contractBehaviourDeclaration(_), .eventDeclaration(_):
      return true
    case .functionDeclaration(_), .specialDeclaration(_),
         .functionSignatureDeclaration(_), .specialSignatureDeclaration(_):
      return false
    }
  }

  func isStructTraitMember(member: TraitMember) -> Bool {
    return !isContractTraitMember(member: member)
  }


  // MARK: Variable
  public func process(variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    var passContext = passContext
    var diagnostics = [Diagnostic]()
    let environment = passContext.environment!

    // Check valid modifiers
     if variableDeclaration.isMutating {
       if variableDeclaration.isConstant {
          diagnostics.append(.mutatingConstant(variableDeclaration))
       }
       else if variableDeclaration.isVariable {
          diagnostics.append(.mutatingVariable(variableDeclaration))
       }
     }

     if variableDeclaration.isPublic {
       if variableDeclaration.isConstant {
        diagnostics.append(.publicLet(variableDeclaration))
       }
       if variableDeclaration.isVisible {
         diagnostics.append(.publicAndVisible(variableDeclaration))
       }
     }

    // Ensure that the type is declared.
    if case .userDefinedType(let typeIdentifier) = variableDeclaration.type.rawType, !environment.isTypeDeclared(typeIdentifier) {
      diagnostics.append(.useOfUndeclaredType(variableDeclaration.type))
    }

    if passContext.inFunctionOrInitializer {
      if let conflict = passContext.scopeContext!.declaration(for: variableDeclaration.identifier.name) {
        diagnostics.append(.invalidRedeclaration(variableDeclaration.identifier, originalSource: conflict.identifier))
      }

      // We're in a function. Record the local variable declaration.
      passContext.scopeContext?.localVariables += [variableDeclaration]
    } else if let enclosingType = passContext.enclosingTypeIdentifier?.name {
      // It's a property declaration.
      if let conflict = environment.conflictingPropertyDeclaration(for: variableDeclaration.identifier, in: enclosingType) {
        diagnostics.append(.invalidRedeclaration(variableDeclaration.identifier, originalSource: conflict))
      }

      // Whether the enclosing type has an initializer defined.
      let isInitializerDeclared: Bool

      if let contractStateDeclarationContext = passContext.contractStateDeclarationContext {
        isInitializerDeclared = environment.publicInitializer(forContract: contractStateDeclarationContext.contractIdentifier.name) != nil
      } else if let structName = passContext.structDeclarationContext?.structIdentifier.name{
        isInitializerDeclared = environment.initializers(in: structName).count > 0
      } else {
        isInitializerDeclared = false
      }

      // This is a state property declaration.

      // If a default value is assigned, it should not refer to another property.

      if variableDeclaration.assignedExpression == nil, !isInitializerDeclared, passContext.eventDeclarationContext == nil {
        // The contract has no public initializer, so a default value must be provided.

        diagnostics.append(.statePropertyIsNotAssignedAValue(variableDeclaration))
      }
    }

    return ASTPassResult(element: variableDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  // MARK: Function
  public func process(functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    var diagnostics = [Diagnostic]()

    let enclosingType = passContext.enclosingTypeIdentifier!.name
    if let conflict = passContext.environment!.conflictingFunctionDeclaration(for: functionDeclaration, in: enclosingType) {
      diagnostics.append(.invalidRedeclaration(functionDeclaration.identifier, originalSource: conflict))
    }

    let signature = functionDeclaration.signature
    let implicitParameters = signature.parameters.filter { $0.isImplicit }
    let payableValueParameters = signature.parameters.filter { $0.isPayableValueParameter }
    if functionDeclaration.isPayable {
      // If a function is marked with the @payable annotation, ensure it contains one compatible payable parameter, and no other implicit parameters.
      if payableValueParameters.count > 1 {
        // If too many arguments are compatible, emit an error.
        diagnostics.append(.ambiguousPayableValueParameter(functionDeclaration))
      } else if payableValueParameters.count == 0 {
        // If not enough arguments are compatible, emit an error.
        diagnostics.append(.payableFunctionDoesNotHavePayableValueParameter(functionDeclaration))
      } else if implicitParameters.count != payableValueParameters.count {
        // If all implicit parameters are not payable value parameters, emit an error.
        diagnostics.append(.payableFunctionHasNonPayableValueParameter(functionDeclaration))
      }
    } else {
      // If a function is not marked with payable annotation, ensure that it does not contain any implicit parameters.
      for parameter in implicitParameters {
        diagnostics.append(.invalidImplicitParameter(functionDeclaration, parameter.identifier))
      }
    }

    if functionDeclaration.isPublic {
      let dynamicParameters = signature.parameters.filter { $0.type.rawType.isDynamicType && !$0.isImplicit }
      if !dynamicParameters.isEmpty {
        diagnostics.append(.useOfDynamicParamaterInFunctionDeclaration(functionDeclaration, dynamicParameters: dynamicParameters))
      }
    }

    // A function may not return a struct type.
    if let rawType = functionDeclaration.signature.resultType?.rawType, case .userDefinedType(_) = rawType {
      diagnostics.append(.invalidReturnTypeInFunction(functionDeclaration))
    }

    let statements = functionDeclaration.body

    // Find a statement after the first return/become in the function.

    let remaining = statements.drop(while: { !$0.isEnding })
    let returns: [ReturnStatement] = statements.compactMap { statement in
      if case .returnStatement(let returnStatement) = statement { return returnStatement } else { return nil }
    }
    let becomes: [BecomeStatement] = statements.compactMap { statement in
      if case .becomeStatement(let becomeStatement) = statement { return becomeStatement } else { return nil }
    }

    let remainingNonEndingStatements = remaining.filter({!$0.isEnding})

    remainingNonEndingStatements.forEach { statement in
      // Emit a warning if there is code after an ending statement.
      diagnostics.append(.codeAfterReturn(statement))
    }

    if returns.isEmpty,
      let resultType = functionDeclaration.signature.resultType {
      // Emit an error if a non-void function doesn't have a return statement.
      diagnostics.append(.missingReturnInNonVoidFunction(closeBraceToken: functionDeclaration.closeBraceToken, resultType: resultType))
    }

    // Check becomes are after returns
    let becomesBeforeAReturn = becomes.filter { become in
      returns.contains(where: { (returnStatement) -> Bool in
        return returnStatement.sourceLocation > become.sourceLocation
      })
    }

    if !becomesBeforeAReturn.isEmpty {
      becomesBeforeAReturn.forEach { (stmt) in
        diagnostics.append(.becomeBeforeReturn(stmt))
      }
    }

    // Add error for each return apart from the last
    returns.dropLast().forEach { statement in
      diagnostics.append(.multipleReturns(statement))
    }
    // Add warning for each become apart from the last
    becomes.dropLast().forEach { statement in
      diagnostics.append(.multipleBecomes(statement))
    }

    return ASTPassResult(element: functionDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  public func postProcess(functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    // Called after all the statements in a function have been visited.

    let mutatingExpressions = passContext.mutatingExpressions ?? []
    var diagnostics = [Diagnostic]()

    if functionDeclaration.isMutating, mutatingExpressions.isEmpty {
      // The function is declared mutating but its body does not contain any mutating expression.
      diagnostics.append(.functionCanBeDeclaredNonMutating(functionDeclaration.mutatingToken))
    }

    // Clear the context in preparation for the next time we visit a function declaration.
    let passContext = passContext.withUpdates { $0.mutatingExpressions = nil }

    var functionDeclaration = functionDeclaration
    functionDeclaration.scopeContext = passContext.scopeContext
    return ASTPassResult(element: functionDeclaration, diagnostics: diagnostics, passContext: passContext)
  }


  // MARK: Special
  public func process(specialDeclaration: SpecialDeclaration, passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    let enclosingType = passContext.enclosingTypeIdentifier!.name
    let environment = passContext.environment!
    var diagnostics = [Diagnostic]()

    if specialDeclaration.isFallback {
      if !specialDeclaration.signature.parameters.isEmpty {
        diagnostics.append(.fallbackDeclaredWithArguments(specialDeclaration))
      }
      let complexStatements = specialDeclaration.body.filter({isComplexStatement($0, env: environment, enclosingType: enclosingType)})
      if !complexStatements.isEmpty || specialDeclaration.body.count > 2 {
        diagnostics.append(.fallbackShouldBeSimple(specialDeclaration, complexStatements: complexStatements))
      }
    }

    // Gather properties of the enclosing type which haven't been assigned a default value.
    let properties = environment.propertyDeclarations(in: enclosingType).filter { propertyDeclaration in
      return propertyDeclaration.value == nil
    }

    let passContext = passContext.withUpdates {
      $0.unassignedProperties = properties
    }

    return ASTPassResult(element: specialDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  private func isComplexStatement(_ statement: Statement, env environment: Environment, enclosingType: RawTypeIdentifier) -> Bool {
    switch statement {
    case .expression(let expression):
      switch expression {
      case .binaryExpression(let binaryExpression):
        if binaryExpression.op.kind == .punctuation(.equal) {
          return true
        }
      case .functionCall(let function):
        let match = environment.matchFunctionCall(function, enclosingType: enclosingType, typeStates: [], callerCapabilities: [], scopeContext: ScopeContext())
        if case .matchedFunction(let functionInformation) = match,
          !functionInformation.isMutating {
          return false
        }
        if case .matchedEvent(_) = environment.matchEventCall(function, enclosingType: enclosingType, scopeContext: ScopeContext()) {
          return false
        }
        return true
      case .identifier(_), .inoutExpression(_), .literal(_), .arrayLiteral(_),
           .dictionaryLiteral(_), .self(_), .variableDeclaration(_), .bracketedExpression(_),
           .subscriptExpression(_),  .range(_):
        return false
      case .rawAssembly(_), .sequence(_):
        return true
      case .attemptExpression(_):
        return true
      }
    case .ifStatement(_):
      return false
    case .returnStatement(_), .forStatement(_), .becomeStatement(_):
      return true
    case .emitStatement(_):
      return false
    }
    return true
  }

  public func postProcess(specialDeclaration: SpecialDeclaration, passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    var diagnostics = [Diagnostic]()
    var passContext = passContext

    // If we are in a contract behavior declaration, of a contract, check there is only one public initializer.
    if let context = passContext.contractBehaviorDeclarationContext, passContext.traitDeclarationContext == nil, specialDeclaration.isPublic {
      let contractName = context.contractIdentifier.name

      // The caller capability block in which this initializer appears should be scoped by "any".
      if !context.callerCapabilities.contains(where: { $0.isAny }) {
        if specialDeclaration.isInit {
          diagnostics.append(.contractInitializerNotDeclaredInAnyCallerCapabilityBlock(specialDeclaration))
        } else if specialDeclaration.isFallback {
          diagnostics.append(.contractFallbackNotDeclaredInAnyCallerCapabilityBlock(specialDeclaration))
        }
      } else {
        if let publicFallback = passContext.environment!.publicFallback(forContract: contractName),
          publicFallback.sourceLocation != specialDeclaration.sourceLocation,
          specialDeclaration.isFallback {
          diagnostics.append(.multiplePublicFallbacksDefined(specialDeclaration, originalFallbackLocation: publicFallback.sourceLocation))
        } else if let publicInitializer = passContext.environment!.publicInitializer(forContract: contractName),
          publicInitializer.sourceLocation != specialDeclaration.sourceLocation,
          specialDeclaration.isInit {
          // There can be at most one public initializer.
          diagnostics.append(.multiplePublicInitializersDefined(specialDeclaration, originalInitializerLocation: publicInitializer.sourceLocation))
        } else {
          // This is the first public initializer we encounter in this contract.
          if specialDeclaration.isInit {
            passContext.environment!.setPublicInitializer(specialDeclaration, for: contractName)
          } else if specialDeclaration.isFallback {
            passContext.environment!.setPublicFallback(specialDeclaration, for: contractName)
          }
        }
      }

      // Check that stateful contracts have initial state set
      let containsBecome = specialDeclaration.body.contains(where: { statement in
        if case .becomeStatement(_) = statement { return true } else { return false }
      })

      if specialDeclaration.isInit,
        passContext.environment!.isStateful(contractName),
        !containsBecome {
        diagnostics.append(.returnFromInitializerWithoutInitializingState(specialDeclaration))
      }
    }


    // Check all the properties in the type have been assigned.
    if specialDeclaration.isInit, let unassignedProperties = passContext.unassignedProperties {

      if unassignedProperties.count > 0 {
        diagnostics.append(.returnFromInitializerWithoutInitializingAllProperties(specialDeclaration, unassignedProperties: unassignedProperties))
      }
    }

    var specialDeclaration = specialDeclaration
    specialDeclaration.scopeContext = passContext.scopeContext ?? ScopeContext()
    return ASTPassResult(element: specialDeclaration, diagnostics: diagnostics, passContext: passContext)
  }
}


extension ASTPassContext {
  /// The list of unassigned properties in a type.
  var unassignedProperties: [Property]? {
    get { return self[UnassignedPropertiesContextEntry.self] }
    set { self[UnassignedPropertiesContextEntry.self] = newValue }
  }
}

struct UnassignedPropertiesContextEntry: PassContextEntry {
  typealias Value = [Property]
}
