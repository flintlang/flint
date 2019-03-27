import AST

// Collect the shadow variables that are modified by a function
public class ShadowVariablePass: ASTPass {
  private let normaliser: IdentifierNormaliser
  var modifies = [String: Set<String>]()

  private var callerFunctionName: String?

  public init(normaliser: IdentifierNormaliser) {
    self.normaliser = normaliser
  }

  public func process(functionDeclaration: FunctionDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    let enclosingType = passContext.enclosingTypeIdentifier!.name
    let functionName = functionDeclaration.name
    let parameterTypes = functionDeclaration.signature.parameters.map({ $0.type.rawType })
    self.callerFunctionName = normaliseFunctionName(functionName: functionName,
                                               parameterTypes: parameterTypes,
                                               enclosingType: enclosingType)
    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(functionDeclaration: FunctionDeclaration,
                          passContext: ASTPassContext) -> ASTPassResult<FunctionDeclaration> {
    self.callerFunctionName = nil
    return ASTPassResult(element: functionDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(specialDeclaration: SpecialDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    let enclosingType = passContext.enclosingTypeIdentifier!.name
    let functionName = specialDeclaration.asFunctionDeclaration.name
    let parameterTypes = specialDeclaration.asFunctionDeclaration.signature.parameters.map({ $0.type.rawType })
    self.callerFunctionName = normaliseFunctionName(functionName: functionName,
                                               parameterTypes: parameterTypes,
                                               enclosingType: enclosingType)
    if let currentFunction = callerFunctionName,
      specialDeclaration.isInit,
      passContext.environment!.isStructDeclared(enclosingType) {
      var currentModifies = modifies[currentFunction] ?? Set<String>()
      // Struct initialiser modifies next instance
      currentModifies.insert(normaliser.generateStructInstanceVariable(structName: passContext.enclosingTypeIdentifier!.name))
      modifies[currentFunction] = currentModifies
    }
    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(specialDeclaration: SpecialDeclaration,
                          passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    self.callerFunctionName = nil
    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(becomeStatement: BecomeStatement,
                      passContext: ASTPassContext) -> ASTPassResult<BecomeStatement> {
    if let currentFunction = callerFunctionName {
      var currentModifies = modifies[currentFunction] ?? Set<String>()
      currentModifies.insert(normaliser.generateStateVariable(passContext.enclosingTypeIdentifier!.name))
    }
    return ASTPassResult(element: becomeStatement, diagnostics: [], passContext: passContext)
  }

  private func normaliseFunctionName(functionName: String,
                                     parameterTypes: [RawType],
                                     enclosingType: String) -> String {
      return normaliser.translateGlobalIdentifierName(functionName + parameterTypes.reduce("", { $0 + $1.name }),
                                                      tld: enclosingType)
  }
}
