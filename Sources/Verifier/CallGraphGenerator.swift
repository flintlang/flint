import AST

// Fill the environment's call graph
public class CallGraphGenerator: ASTPass {
  private let normaliser: IdentifierNormaliser
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

    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }

  public func postProcess(specialDeclaration: SpecialDeclaration,
                          passContext: ASTPassContext) -> ASTPassResult<SpecialDeclaration> {
    self.callerFunctionName = nil

    return ASTPassResult(element: specialDeclaration, diagnostics: [], passContext: passContext)
  }

  public func process(functionCall: FunctionCall,
                      passContext: ASTPassContext) -> ASTPassResult<FunctionCall> {
    var updatedContext = passContext
    var environment = passContext.environment!
    let currentType = passContext.enclosingTypeIdentifier!.name
    let enclosingType = functionCall.identifier.enclosingType ?? currentType

    switch functionCall.identifier.name {
    case "assert", "fatalError", "flint$fatalError", "send", "flint$send":
      return ASTPassResult(element: functionCall, diagnostics: [], passContext: passContext)
    default: break
    }

    if let scopeContext = passContext.scopeContext {
      let matchedCall = environment.matchFunctionCall(functionCall,
                                                      enclosingType: enclosingType,
                                                      typeStates: [],
                                                      callerProtections: [],
                                                      scopeContext: scopeContext)
      var parameterTypes: [RawType]
      switch matchedCall {
      case .matchedFunction(let functionInformation):
        parameterTypes = functionInformation.parameterTypes

      case .matchedGlobalFunction(let functionInformation):
        parameterTypes = functionInformation.parameterTypes

      case .matchedInitializer(let specialInformation):
        // Initialisers do not return values -> although struct inits do = ints
        // TODO: Assume only for struct initialisers. Need to implement for contract initialisers/fallback functions?

        // This only works for struct initialisers.
        parameterTypes = specialInformation.parameterTypes
        print(currentType)
        print(enclosingType)

      case .matchedFallback(let specialInformation):
        //TODO: Handle fallback functions
        print("Call graph - Handle fallback calls")
        print(specialInformation)
        fatalError()

      case .failure(let candidates):
        print("call graph generation - could not find function for call: \(functionCall)")
        print(currentType)
        print(enclosingType)
        print(candidates)
        fatalError()

      default:
        print("call graph generation - default: \(functionCall)")
        print(currentType)
        fatalError()
      }

      let normalisedName = normaliseFunctionName(functionName: functionCall.identifier.name,
                                                 parameterTypes: parameterTypes,
                                                 enclosingType: enclosingType)
      if let currentFunction = callerFunctionName {
        environment.addFunctionCall(caller: currentFunction, callee: normalisedName)
        updatedContext.environment = environment
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
