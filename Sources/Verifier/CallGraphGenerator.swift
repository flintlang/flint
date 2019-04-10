import AST

// Fill the environment's call graph
public class CallGraphGenerator: ASTPass {
  private let normaliser = IdentifierNormaliser()
  private var callerFunctionName: String?

  public init() {}

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

    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(specialDeclaration: SpecialDeclaration,
                          passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    self.callerFunctionName = nil

    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(variableDeclaration: VariableDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<VariableDeclaration> {
    // Need to record the local variables, so the matchFunctionCall method works,
    // correctly resolves function calls with struct types as parameters
    var updatedContext = passContext
    if passContext.inFunctionOrInitializer {
      // We're in a function. Record the local variable declaration.
      updatedContext.scopeContext?.localVariables.append(variableDeclaration)
    }
    return ASTPassResult(element: variableDeclaration, diagnostics: [], passContext: updatedContext)
  }

  public func postProcess(functionCall: FunctionCall,
                          passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    var updatedContext = passContext
    let environment = passContext.environment!
    let currentType = passContext.enclosingTypeIdentifier!.name
    let enclosingType = functionCall.identifier.enclosingType ?? currentType

    switch functionCall.identifier.name {
    case "assert", "fatalError", "flint$fatalError", "send", "flint$send":
      return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
    default: break
    }

    if let scopeContext = passContext.scopeContext,
       let currentFunction = callerFunctionName {
      let matchedCall = environment.matchFunctionCall(functionCall,
                                                      enclosingType: enclosingType,
                                                      typeStates: [],
                                                      callerProtections: [],
                                                      scopeContext: scopeContext)
      functionCallSwitch: switch matchedCall {
      case .matchedFunction(let functionInformation):
        let normalisedFunctionName = normaliseFunctionName(functionName: functionCall.identifier.name,
                                                   parameterTypes: functionInformation.parameterTypes,
                                                   enclosingType: enclosingType)
        environment.addFunctionCall(caller: currentFunction, callee: normalisedFunctionName)
        updatedContext.environment = environment

      case .matchedInitializer(let specialInformation):
        // Initialisers do not return values -> although struct inits do = ints
        // TODO: Assume only for struct initialisers. Need to implement for fallback functions?

        // This only works for struct initialisers.

        let normalisedFunctionName = normaliseFunctionName(functionName: specialInformation.declaration.asFunctionDeclaration.name,
                                                           parameterTypes: specialInformation.parameterTypes,
                                                           enclosingType: functionCall.identifier.name)
        environment.addFunctionCall(caller: currentFunction, callee: normalisedFunctionName)
        updatedContext.environment = environment

      case .failure(let candidates):
        // Check if event, and resume, else abort
        switch environment.matchEventCall(functionCall,
                                          enclosingType: enclosingType,
                                          scopeContext: scopeContext) {
        case .failure(let cs):
          print(cs)
        default: break functionCallSwitch
        }

        print("call graph generation - could not find function for call: \(functionCall)")
        print(scopeContext)
        print(functionCall)
        print(currentType)
        print(enclosingType)
        print(candidates)
        fatalError()

      default:
        print("call graph generation - default: \(functionCall)")
        print(currentType)
        print(matchedCall)
        fatalError()
      }
    }

    return ASTPassResult(element: functionCall, diagnostics: [], passContext: updatedContext)
  }

  private func normaliseFunctionName(functionName: String,
                                     parameterTypes: [RawType],
                                     enclosingType: String) -> String {
      return normaliser.translateGlobalIdentifierName(functionName + parameterTypes.reduce("", { $0 + $1.name }),
                                                      tld: enclosingType)
  }
}
