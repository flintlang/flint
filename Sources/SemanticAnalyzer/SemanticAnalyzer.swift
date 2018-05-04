//
//  SemanticAnalyzer.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 12/26/17.
//

import AST

/// The `ASTPass` performing semantic analysis.
public struct SemanticAnalyzer: ASTPass {
  public init() {}

  public func process(topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule> {
    return ASTPassResult(element: topLevelModule, diagnostics: [], passContext: passContext)
  }

  public func process(topLevelDeclaration: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration> {
    return ASTPassResult(element: topLevelDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    var diagnostics = [Diagnostic]()
    if let conflict = passContext.environment!.conflictingTypeDeclaration(for: contractDeclaration.identifier) {
      diagnostics.append(.invalidRedeclaration(contractDeclaration.identifier, originalSource: conflict))
    }
    return ASTPassResult(element: contractDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    var diagnostics = [Diagnostic]()

    let environment = passContext.environment!

    if !environment.isContractDeclared(contractBehaviorDeclaration.contractIdentifier.name) {
      // The contract behavior declaration could not be associated with any contract declaration.
      diagnostics.append(.contractBehaviorDeclarationNoMatchingContract(contractBehaviorDeclaration))
    }

    // Create a context containing the contract the methods are defined for, and the caller capabilities the functions
    // within it are scoped by.
    let declarationContext = ContractBehaviorDeclarationContext(contractIdentifier: contractBehaviorDeclaration.contractIdentifier, callerCapabilities: contractBehaviorDeclaration.callerCapabilities)

    let passContext = passContext.withUpdates { $0.contractBehaviorDeclarationContext = declarationContext }

    return ASTPassResult(element: contractBehaviorDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(contractBehaviorMember: ContractBehaviorMember, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorMember> {
    return ASTPassResult(element: contractBehaviorMember, diagnostics: [], passContext: passContext)
  }

  public func process(structDeclaration: StructDeclaration, passContext: ASTPassContext) -> ASTPassResult<StructDeclaration> {
    var diagnostics = [Diagnostic]()
    if let conflict = passContext.environment!.conflictingTypeDeclaration(for: structDeclaration.identifier) {
      diagnostics.append(.invalidRedeclaration(structDeclaration.identifier, originalSource: conflict))
    }
    return ASTPassResult(element: structDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(structMember: StructMember, passContext: ASTPassContext) -> ASTPassResult<StructMember> {
    return ASTPassResult(element: structMember, diagnostics: [], passContext: passContext)
  }

  public func process(variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    var passContext = passContext
    var diagnostics = [Diagnostic]()
    let environment = passContext.environment!

    let inFunctionOrInitializer = passContext.functionDeclarationContext != nil || passContext.initializerDeclarationContext != nil

    if inFunctionOrInitializer {
      if let conflict = passContext.scopeContext!.variableDeclaration(for: variableDeclaration.identifier.name) {
        diagnostics.append(.invalidRedeclaration(variableDeclaration.identifier, originalSource: conflict.identifier))
      }

      // We're in a function. Record the local variable declaration.
      passContext.scopeContext?.localVariables += [variableDeclaration]
    } else {
      // It's a property declaration.

      let enclosingType = enclosingTypeIdentifier(in: passContext).name
      if let conflict = environment.conflictingPropertyDeclaration(for: variableDeclaration.identifier, in: enclosingType) {
        diagnostics.append(.invalidRedeclaration(variableDeclaration.identifier, originalSource: conflict))
      }

      // Whether the enclosing type has an initializer defined.
      let isInitializerDeclared: Bool

      if let contractStateDeclarationContext = passContext.contractStateDeclarationContext {
        isInitializerDeclared = environment.publicInitializer(forContract: contractStateDeclarationContext.contractIdentifier.name) != nil
      } else {
        isInitializerDeclared = environment.initializers(in: passContext.structDeclarationContext!.structIdentifier.name).count > 0
      }

      // This is a state property declaration.

      // If a default value is assigned, it should be a literal.

      if let assignedExpression = variableDeclaration.assignedExpression {
        if !assignedExpression.isLiteral {
          diagnostics.append(.statePropertyDeclarationIsAssignedANonLiteralExpression(variableDeclaration))
        }
      } else {
        if variableDeclaration.type.rawType.isBuiltInType && !variableDeclaration.type.rawType.isEventType && !isInitializerDeclared {
          // The contract has no public initializer, so a default value must be provided.

          diagnostics.append(.statePropertyIsNotAssignedAValue(variableDeclaration))
        }
      }
    }

    return ASTPassResult(element: variableDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(functionDeclaration: FunctionDeclaration, passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    var diagnostics = [Diagnostic]()

    let enclosingType = enclosingTypeIdentifier(in: passContext).name
    if let conflict = passContext.environment!.conflictingFunctionDeclaration(for: functionDeclaration.identifier, in: enclosingType) {
      diagnostics.append(.invalidRedeclaration(functionDeclaration.identifier, originalSource: conflict))
    }

    if functionDeclaration.isPayable {
      // If a function is marked with the @payable annotation, ensure it contains a compatible payable parameter.
      let payableValueParameters = functionDeclaration.parameters.filter { $0.isPayableValueParameter }
      if payableValueParameters.count > 1 {
        // If too many arguments are compatible, emit an error.
        diagnostics.append(.ambiguousPayableValueParameter(functionDeclaration))
      } else if payableValueParameters.count == 0 {
        // If not enough arguments are compatible, emit an error.
        diagnostics.append(.payableFunctionDoesNotHavePayableValueParameter(functionDeclaration))
      }
    }

    let statements = functionDeclaration.body

    // Find a return statement in the function.
    let returnStatementIndex = statements.index(where: { statement in
      if case .returnStatement(_) = statement { return true }
      return false
    })

    if let returnStatementIndex = returnStatementIndex {
      if returnStatementIndex != statements.count - 1 {
        let nextStatement = statements[returnStatementIndex + 1]

        // Emit a warning if there is code after a return statement.
        diagnostics.append(.codeAfterReturn(nextStatement))
      }
    } else {
      if let resultType = functionDeclaration.resultType {
        // Emit an error if a non-void function doesn't have a return statement.
        diagnostics.append(.missingReturnInNonVoidFunction(closeBraceToken: functionDeclaration.closeBraceToken, resultType: resultType))
      }
    }
    return ASTPassResult(element: functionDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(initializerDeclaration: InitializerDeclaration, passContext: ASTPassContext) -> ASTPassResult<InitializerDeclaration> {
    let enclosingType = enclosingTypeIdentifier(in: passContext).name
    let environment = passContext.environment!

    // Gather properties of the enclosing type which haven't been assigned a default value.
    let properties = environment.propertyDeclarations(in: enclosingType).filter { propertyDeclaration in
      return propertyDeclaration.assignedExpression == nil
    }

    let passContext = passContext.withUpdates {
      $0.unassignedProperties = properties
    }

    return ASTPassResult(element: initializerDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(attribute: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute> {
    return ASTPassResult(element: attribute, diagnostics: [], passContext: passContext)
  }

  public func process(parameter: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter> {
    let type = parameter.type
    var diagnostics = [Diagnostic]()

    if passContext.environment!.isReferenceType(type.name), !parameter.isInout {
      // Ensure all structs are passed by reference, for now.
      diagnostics.append(Diagnostic(severity: .error, sourceLocation: parameter.sourceLocation, message: "Structs cannot be passed by value yet, and have to be passed inout"))
    }

    return ASTPassResult(element: parameter, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(typeAnnotation: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation> {
    return ASTPassResult(element: typeAnnotation, diagnostics: [], passContext: passContext)
  }

  public func process(identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier> {
    var identifier = identifier
    var passContext = passContext
    var diagnostics = [Diagnostic]()

    let inFunctionDeclaration = passContext.functionDeclarationContext != nil
    let inInitializerDeclaration = passContext.initializerDeclarationContext != nil
    let inFunctionOrInitializer = inFunctionDeclaration || inInitializerDeclaration

    if let isFunctionCall = passContext.isFunctionCall, isFunctionCall {
      // If the identifier is the name of a function call, do nothing. The function call will be matched in
      // `process(functionCall:passContext:)`.
    } else if inFunctionOrInitializer {
      // The identifier is used within the body of a function or an initializer

      // The identifier is used an l-value (the left-hand side of an assignment).
      let asLValue = passContext.asLValue ?? false

      if identifier.enclosingType == nil {
        // The identifier has no explicit enclosing type, such as in the expression `foo` instead of `a.foo`.

        let scopeContext = passContext.scopeContext!
        if let variableDeclaration = scopeContext.variableDeclaration(for: identifier.name) {
          if variableDeclaration.isConstant, asLValue {
            // The variable is a constant but is attempted to be reassigned.
            diagnostics.append(.reassignmentToConstant(identifier, variableDeclaration.sourceLocation))
          }
        } else {
          // If the variable is not declared locally, assign its enclosing type to the struct or contract behavior
          // declaration in which the function appears.
          identifier.enclosingType = enclosingTypeIdentifier(in: passContext).name
        }
      }

      if let enclosingType = identifier.enclosingType {
        // The identifier has an explicit enclosing type, such as `a` in the expression `a.foo`.

        if !passContext.environment!.isPropertyDefined(identifier.name, enclosingType: enclosingType) {
          // The property is not defined in the enclosing type.
          diagnostics.append(.useOfUndeclaredIdentifier(identifier))
          passContext.environment!.addUsedUndefinedVariable(identifier, enclosingType: enclosingType)
        } else if asLValue {

          if passContext.environment!.isPropertyConstant(identifier.name, enclosingType: enclosingType) {
            // Retrieve the source location of that property's declaration.
            let declarationSourceLocation = passContext.environment!.propertyDeclarationSourceLocation(identifier.name, enclosingType: enclosingType)!
            
            if !inInitializerDeclaration || passContext.environment!.isPropertyAssignedDefaultValue(identifier.name, enclosingType: enclosingType) {
              // The state property is a constant but is attempted to be reassigned.
              diagnostics.append(.reassignmentToConstant(identifier, declarationSourceLocation))
            }
          }

          // In initializers.
          if let _ = passContext.initializerDeclarationContext {
            // Check if the property has been marked as assigned yet.
            if let first = passContext.unassignedProperties!.index(where: { $0.identifier.name == identifier.name && $0.identifier.enclosingType == identifier.enclosingType }) {
              // Mark the property as assigned.
              passContext.unassignedProperties!.remove(at: first)
            }
          }

          if let functionDeclarationContext = passContext.functionDeclarationContext {
            // The variable is being mutated in a function.
            if !functionDeclarationContext.isMutating {
              // The function is declared non-mutating.
              diagnostics.append(.useOfMutatingExpressionInNonMutatingFunction(.identifier(identifier), functionDeclaration: functionDeclarationContext.declaration))
            }
            // Record the mutating expression in the context.
            addMutatingExpression(.identifier(identifier), passContext: &passContext)
          }
        }
      }
    }

    return ASTPassResult(element: identifier, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(type: Type, passContext: ASTPassContext) -> ASTPassResult<Type> {
    return ASTPassResult(element: type, diagnostics: [], passContext: passContext)
  }

  public func process(callerCapability: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability> {
    let contractBehaviorDeclarationContext = passContext.contractBehaviorDeclarationContext!
    let environment = passContext.environment!
    var diagnostics = [Diagnostic]()

    if !callerCapability.isAny && !environment.containsCallerCapability(callerCapability, enclosingType: contractBehaviorDeclarationContext.contractIdentifier.name) {
      // The caller capability is neither `any` or a valid property in the enclosing contract.
      diagnostics.append(.undeclaredCallerCapability(callerCapability, contractIdentifier: contractBehaviorDeclarationContext.contractIdentifier))
    }

    return ASTPassResult(element: callerCapability, diagnostics: diagnostics, passContext: passContext)
  }

  public func process(expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression> {
    return ASTPassResult(element: expression, diagnostics: [], passContext: passContext)
  }

  public func process(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    return ASTPassResult(element: statement, diagnostics: [], passContext: passContext)
  }
  
  public func process(inoutExpression: InoutExpression, passContext: ASTPassContext) -> ASTPassResult<InoutExpression> {
    return ASTPassResult(element: inoutExpression, diagnostics: [], passContext: passContext)
  }

  public func process(binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    var binaryExpression = binaryExpression

    if case .dot = binaryExpression.opToken {
      // The identifier explicitly refers to a state property, such as in `self.foo`.
      // We set its enclosing type to the type it is declared in.
      let enclosingType = enclosingTypeIdentifier(in: passContext)
      let lhsType = passContext.environment!.type(of: binaryExpression.lhs, enclosingType: enclosingType.name, scopeContext: passContext.scopeContext!)
      binaryExpression.rhs = binaryExpression.rhs.assigningEnclosingType(type: lhsType.name)
    }
    
    return ASTPassResult(element: binaryExpression, diagnostics: [], passContext: passContext)
  }

  public func process(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    if let _ = passContext.initializerDeclarationContext {
      // Function calls are not allowed in initializers yet
      fatalError("Function calls are not allowed in initializers yet.")
    }
    return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
  }

  public func process(arrayLiteral: ArrayLiteral, passContext: ASTPassContext) -> ASTPassResult<AST.ArrayLiteral> {
    return ASTPassResult(element: arrayLiteral, diagnostics: [], passContext: passContext)
  }

  public func process(dictionaryLiteral: AST.DictionaryLiteral, passContext: ASTPassContext) -> ASTPassResult<AST.DictionaryLiteral> {
    return ASTPassResult(element: dictionaryLiteral, diagnostics: [], passContext: passContext)
  }

  /// Whether an expression refers to a state property.
  private func isStorageReference(expression: Expression, scopeContext: ScopeContext) -> Bool {
    switch expression {
    case .self(_): return true
    case .identifier(let identifier): return !scopeContext.containsVariableDeclaration(for: identifier.name)
    case .inoutExpression(let inoutExpression): return isStorageReference(expression: inoutExpression.expression, scopeContext: scopeContext)
    case .binaryExpression(let binaryExpression):
      return isStorageReference(expression: binaryExpression.lhs, scopeContext: scopeContext)
    default: return false
    }
  }

  public func process(subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    return ASTPassResult(element: subscriptExpression, diagnostics: [], passContext: passContext)
  }

  public func process(returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    return ASTPassResult(element: returnStatement, diagnostics: [], passContext: passContext)
  }

  public func process(ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    return ASTPassResult(element: ifStatement, diagnostics: [], passContext: passContext)
  }

  public func postProcess(topLevelModule: TopLevelModule, passContext: ASTPassContext) -> ASTPassResult<TopLevelModule> {
    return ASTPassResult(element: topLevelModule, diagnostics: [], passContext: passContext)
  }

  public func postProcess(topLevelDeclaration: TopLevelDeclaration, passContext: ASTPassContext) -> ASTPassResult<TopLevelDeclaration> {
    return ASTPassResult(element: topLevelDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(contractDeclaration: ContractDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractDeclaration> {
    return ASTPassResult(element: contractDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(contractBehaviorDeclaration: ContractBehaviorDeclaration, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    return ASTPassResult(element: contractBehaviorDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(contractBehaviorMember: ContractBehaviorMember, passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorMember> {
    return ASTPassResult(element: contractBehaviorMember, diagnostics: [], passContext: passContext)
  }

  public func postProcess(structDeclaration: StructDeclaration, passContext: ASTPassContext) -> ASTPassResult<StructDeclaration> {
    return ASTPassResult(element: structDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(structMember: StructMember, passContext: ASTPassContext) -> ASTPassResult<StructMember> {
    return ASTPassResult(element: structMember, diagnostics: [], passContext: passContext)
  }

  public func postProcess(variableDeclaration: VariableDeclaration, passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    return ASTPassResult(element: variableDeclaration, diagnostics: [], passContext: passContext)
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
    return ASTPassResult(element: functionDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  public func postProcess(initializerDeclaration: InitializerDeclaration, passContext: ASTPassContext) -> ASTPassResult<InitializerDeclaration> {
    var diagnostics = [Diagnostic]()
    var passContext = passContext

    // If we are in a contract behavior declaration, check there is only one public initializer.
    if let context = passContext.contractBehaviorDeclarationContext, initializerDeclaration.isPublic {
      let contractName = context.contractIdentifier.name

      // The caller capability block in which this initializer appears should be scoped by "any".
      if !context.callerCapabilities.contains(where: { $0.isAny }) {
        diagnostics.append(.contractInitializerNotDeclaredInAnyCallerCapabilityBlock(initializerDeclaration))
      } else {
        if let publicInitializer = passContext.environment!.publicInitializer(forContract: contractName), publicInitializer.sourceLocation != initializerDeclaration.sourceLocation {
          // There can be at most one public initializer.
          diagnostics.append(.multiplePublicInitializersDefined(initializerDeclaration, originalInitializerLocation: publicInitializer.sourceLocation))
        } else {
          // This is the first public initializer we encounter in this contract.
          passContext.environment!.setPublicInitializer(initializerDeclaration, forContract: contractName)
        }
      }
    }

    // Check all the properties in the type have been assigned.
    if let unassignedProperties = passContext.unassignedProperties {
      let propertiesWithBuiltInTypes = unassignedProperties.filter { $0.type.rawType.isBuiltInType && !$0.type.rawType.isEventType }
      
      // For now, only non user-defined types need to be assigned a value.
      if propertiesWithBuiltInTypes.count > 0 {
        diagnostics.append(.returnFromInitializerWithoutInitializingAllProperties(initializerDeclaration, unassignedProperties: unassignedProperties))
      }
    }

    return ASTPassResult(element: initializerDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  public func postProcess(attribute: Attribute, passContext: ASTPassContext) -> ASTPassResult<Attribute> {
    return ASTPassResult(element: attribute, diagnostics: [], passContext: passContext)
  }

  public func postProcess(parameter: Parameter, passContext: ASTPassContext) -> ASTPassResult<Parameter> {
    return ASTPassResult(element: parameter, diagnostics: [], passContext: passContext)
  }

  public func postProcess(typeAnnotation: TypeAnnotation, passContext: ASTPassContext) -> ASTPassResult<TypeAnnotation> {
    return ASTPassResult(element: typeAnnotation, diagnostics: [], passContext: passContext)
  }

  public func postProcess(identifier: Identifier, passContext: ASTPassContext) -> ASTPassResult<Identifier> {
    return ASTPassResult(element: identifier, diagnostics: [], passContext: passContext)
  }

  public func postProcess(type: Type, passContext: ASTPassContext) -> ASTPassResult<Type> {
    return ASTPassResult(element: type, diagnostics: [], passContext: passContext)
  }

  public func postProcess(callerCapability: CallerCapability, passContext: ASTPassContext) -> ASTPassResult<CallerCapability> {
    return ASTPassResult(element: callerCapability, diagnostics: [], passContext: passContext)
  }

  public func postProcess(expression: Expression, passContext: ASTPassContext) -> ASTPassResult<Expression> {
    return ASTPassResult(element: expression, diagnostics: [], passContext: passContext)
  }

  public func postProcess(statement: Statement, passContext: ASTPassContext) -> ASTPassResult<Statement> {
    return ASTPassResult(element: statement, diagnostics: [], passContext: passContext)
  }
  
  public func postProcess(inoutExpression: InoutExpression, passContext: ASTPassContext) -> ASTPassResult<InoutExpression> {
    return ASTPassResult(element: inoutExpression, diagnostics: [], passContext: passContext)
  }

  public func postProcess(binaryExpression: BinaryExpression, passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    return ASTPassResult(element: binaryExpression, diagnostics: [], passContext: passContext)
  }

  public func postProcess(functionCall: FunctionCall, passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    // Called once we've visited the function call's arguments.

    var passContext = passContext
    let environment = passContext.environment!
    let enclosingType = enclosingTypeIdentifier(in: passContext).name
    let callerCapabilities = passContext.contractBehaviorDeclarationContext?.callerCapabilities ?? []

    var diagnostics = [Diagnostic]()

    if let functionDeclarationContext = passContext.functionDeclarationContext {
      // Find the function declaration associated with this function call.
      switch environment.matchFunctionCall(functionCall, enclosingType: functionCall.identifier.enclosingType ?? enclosingType, callerCapabilities: callerCapabilities, scopeContext: passContext.scopeContext!) {
      case .matchedFunction(let matchingFunction):
        // The function declaration is found.

        if matchingFunction.isMutating {
          // The function is mutating.
          addMutatingExpression(.functionCall(functionCall), passContext: &passContext)

          if !functionDeclarationContext.isMutating {
            // The function in which the function call appears in is not mutating.
            diagnostics.append(.useOfMutatingExpressionInNonMutatingFunction(.functionCall(functionCall), functionDeclaration: functionDeclarationContext.declaration))
          }
        }

        // If there are arguments passed inout which refer to state properties, the enclosing function need to be declared mutating.
        for (argument, parameter) in zip(functionCall.arguments, matchingFunction.declaration.parameters) where parameter.isInout {
          if isStorageReference(expression: argument, scopeContext: passContext.scopeContext!) {
            addMutatingExpression(argument, passContext: &passContext)

            if !functionDeclarationContext.isMutating {
              diagnostics.append(.useOfMutatingExpressionInNonMutatingFunction(.functionCall(functionCall), functionDeclaration: functionDeclarationContext.declaration))
            }
          }
        }

      case .matchedInitializer(_):
        break

      case .failure(let candidates):
        // A matching function declaration couldn't be found. Try to match an event call.
        if environment.matchEventCall(functionCall, enclosingType: enclosingType) == nil {
          diagnostics.append(.noMatchingFunctionForFunctionCall(functionCall, contextCallerCapabilities: callerCapabilities, candidates: candidates))
        }
      }
    }
    
    return ASTPassResult(element: functionCall, diagnostics: diagnostics, passContext: passContext)
  }

  public func postProcess(arrayLiteral: ArrayLiteral, passContext: ASTPassContext) -> ASTPassResult<ArrayLiteral> {
    return ASTPassResult(element: arrayLiteral, diagnostics: [], passContext: passContext)
  }

  public func postProcess(dictionaryLiteral: AST.DictionaryLiteral, passContext: ASTPassContext) -> ASTPassResult<AST.DictionaryLiteral> {
    return ASTPassResult(element: dictionaryLiteral, diagnostics: [], passContext: passContext)
  }

  public func postProcess(subscriptExpression: SubscriptExpression, passContext: ASTPassContext) -> ASTPassResult<SubscriptExpression> {
    return ASTPassResult(element: subscriptExpression, diagnostics: [], passContext: passContext)
  }

  public func postProcess(returnStatement: ReturnStatement, passContext: ASTPassContext) -> ASTPassResult<ReturnStatement> {
    return ASTPassResult(element: returnStatement, diagnostics: [], passContext: passContext)
  }

  public func postProcess(ifStatement: IfStatement, passContext: ASTPassContext) -> ASTPassResult<IfStatement> {
    return ASTPassResult(element: ifStatement, diagnostics: [], passContext: passContext)
  }

  private func addMutatingExpression(_ mutatingExpression: Expression, passContext: inout ASTPassContext) {
    let mutatingExpressions = (passContext.mutatingExpressions ?? []) + [mutatingExpression]
    passContext.mutatingExpressions = mutatingExpressions
  }
}

extension ASTPassContext {
  /// The list of mutating expressions in a function.
  var mutatingExpressions: [Expression]? {
    get { return self[MutatingExpressionContextEntry.self] }
    set { self[MutatingExpressionContextEntry.self] = newValue }
  }

  /// The list of unassigned properties in a type.
  var unassignedProperties: [VariableDeclaration]? {
    get { return self[UnassignedPropertiesContextEntry.self] }
    set { self[UnassignedPropertiesContextEntry.self] = newValue }
  }
}

struct MutatingExpressionContextEntry: PassContextEntry {
  typealias Value = [Expression]
}

struct UnassignedPropertiesContextEntry: PassContextEntry {
  typealias Value = [VariableDeclaration]
}
