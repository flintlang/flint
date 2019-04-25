import AST

// Collect the shadow variables that are modified by a function
class ShadowVariablePass: ASTPass {
  private let normaliser: IdentifierNormaliser
  private let triggers: Trigger
  var modifies = [String: Set<String>]()

  private var callerFunctionName: String?

  init(normaliser: IdentifierNormaliser, triggers: Trigger) {
    self.normaliser = normaliser
    self.triggers = triggers
  }

  func process(functionDeclaration: FunctionDeclaration,
               passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    let enclosingType = passContext.enclosingTypeIdentifier!.name
    let functionName = functionDeclaration.name
    let parameterTypes = functionDeclaration.signature.parameters.map({ $0.type.rawType })
    self.callerFunctionName = normaliseFunctionName(functionName: functionName,
                                               parameterTypes: parameterTypes,
                                               enclosingType: enclosingType)

    // Process for trigger
    let scopeContext = passContext.scopeContext ?? ScopeContext()
    for mutates in triggers.mutates(functionDeclaration, Context(environment: passContext.environment!,
                                                                 enclosingType: enclosingType,
                                                                 scopeContext: scopeContext)) {
      addCurrentFunctionModifies(shadowVariableName: mutates)
    }

    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }

  func postProcess(functionDeclaration: FunctionDeclaration,
                   passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    self.callerFunctionName = nil
    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }

  func process(specialDeclaration: SpecialDeclaration,
               passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    let enclosingType = passContext.enclosingTypeIdentifier!.name
    let functionName = specialDeclaration.asFunctionDeclaration.name
    let parameterTypes = specialDeclaration.asFunctionDeclaration.signature.parameters.map({ $0.type.rawType })
    self.callerFunctionName = normaliseFunctionName(functionName: functionName,
                                                    parameterTypes: parameterTypes,
                                                    enclosingType: enclosingType)
    if specialDeclaration.isInit,
       passContext.environment!.isStructDeclared(enclosingType) {
        // Struct initialiser modifies next instance
        addCurrentFunctionModifies(shadowVariableName: normaliser.generateStructInstanceVariable(structName: passContext.enclosingTypeIdentifier!.name))
    }

    // Process for trigger
    let scopeContext = passContext.scopeContext ?? ScopeContext()
    for mutates in triggers.mutates(specialDeclaration.asFunctionDeclaration, Context(environment: passContext.environment!,
                                                                 enclosingType: enclosingType,
                                                                 scopeContext: scopeContext)) {
      addCurrentFunctionModifies(shadowVariableName: mutates)
    }

    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }

  func postProcess(specialDeclaration: SpecialDeclaration,
                   passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    self.callerFunctionName = nil
    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }

  func process(becomeStatement: BecomeStatement,
               passContext: ASTPassContext) -> ASTPassResult<BecomeStatement> {
    addCurrentFunctionModifies(shadowVariableName: normaliser.generateStateVariable(passContext.enclosingTypeIdentifier!.name))

    return ASTPassResult(element: becomeStatement, diagnostics: [], passContext: passContext)
  }

  // External calls can modify the stateVariable as it could call other functions
  func process(externalCall: ExternalCall,
               passContext: ASTPassContext) -> ASTPassResult<ExternalCall> {
    addCurrentFunctionModifies(shadowVariableName: normaliser.generateStateVariable(passContext.enclosingTypeIdentifier!.name))

    return ASTPassResult(element: externalCall, diagnostics: [], passContext: passContext)
  }


  func process(binaryExpression: BinaryExpression,
               passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {

    // Process for trigger
    let enclosingType = passContext.enclosingTypeIdentifier!.name
    let scopeContext = passContext.scopeContext ?? ScopeContext()
    for mutates in triggers.mutates(binaryExpression, Context(environment: passContext.environment!,
                                                              enclosingType: enclosingType,
                                                              scopeContext: scopeContext)) {
      addCurrentFunctionModifies(shadowVariableName: mutates)
    }

    // Mark that binary expression is assignment
    return ASTPassResult(element: binaryExpression, diagnostics: [], passContext: passContext)
  }

  func postProcess(binaryExpression: BinaryExpression,
                   passContext: ASTPassContext) -> ASTPassResult<BinaryExpression> {
    // Unmark that binary expression is assignment
    return ASTPassResult(element: binaryExpression, diagnostics: [], passContext: passContext)
  }

  func process(parameter: Parameter,
               passContext: ASTPassContext) -> ASTPassResult<Parameter> {

    if parameter.isImplicit, case .inoutType(let innerType) = parameter.type.rawType {
      addCurrentFunctionModifies(shadowVariableName: normaliser.generateStructInstanceVariable(structName: innerType.name))
    }

    let enclosingType = passContext.enclosingTypeIdentifier!.name
    let scopeContext = passContext.scopeContext ?? ScopeContext()
    for mutates in triggers.mutates(parameter, Context(environment: passContext.environment!,
                                                       enclosingType: enclosingType,
                                                       scopeContext: scopeContext)) {
      addCurrentFunctionModifies(shadowVariableName: mutates)
    }
    return ASTPassResult(element: parameter, diagnostics: [], passContext: passContext)
  }

  private func normaliseFunctionName(functionName: String,
                                     parameterTypes: [RawType],
                                     enclosingType: String) -> String {
      return normaliser.translateGlobalIdentifierName(functionName + parameterTypes.reduce("", { $0 + $1.name }),
                                                      tld: enclosingType)
  }

  private func addCurrentFunctionModifies(shadowVariableName: String) {
    if let currentFunction = callerFunctionName {
      var currentModifies = modifies[currentFunction] ?? Set<String>()
      currentModifies.insert(shadowVariableName)
      modifies[currentFunction] = currentModifies
    }
  }
}
