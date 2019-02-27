import AST
import Source
import Lexer
import Foundation

extension BoogieTranslator {
  func getCurrentFunction() -> FunctionDeclaration {
    if let behaviourDeclarationMember = currentBehaviourMember {
      switch behaviourDeclarationMember {
      case .functionDeclaration(let functionDeclaration):
        return functionDeclaration
      case .specialDeclaration(let specialDeclaration):
        return specialDeclaration.asFunctionDeclaration
      default:
        print("Error getting current function - not in a function: \(behaviourDeclarationMember.description)")
      }
    }
    print("Error getting current function - not in a current behaviour declaration")
    fatalError()
  }

  func getCurrentFunctionName() -> String? {
    if let behaviourDeclarationMember = currentBehaviourMember {
      var functionName: String
      let parameterTypes: [RawType]
      switch behaviourDeclarationMember {
      case .functionDeclaration(let functionDeclaration):
        functionName = functionDeclaration.signature.identifier.name
        parameterTypes = functionDeclaration.signature.parameters.map({ $0.type.rawType })
      case .specialDeclaration(let specialDeclaration):
        functionName = specialDeclaration.signature.specialToken.description
        parameterTypes = specialDeclaration.signature.parameters.map({ $0.type.rawType })
      case .functionSignatureDeclaration(let functionSignatureDeclaration):
        functionName = functionSignatureDeclaration.identifier.name
        parameterTypes = functionSignatureDeclaration.parameters.map({ $0.type.rawType })
      case .specialSignatureDeclaration(let specialSignatureDeclaration):
        functionName = specialSignatureDeclaration.specialToken.description
        parameterTypes = specialSignatureDeclaration.parameters.map({ $0.type.rawType })
      }
      return translateGlobalIdentifierName(functionName + parameterTypes.reduce("", { $0 + $1.name }))
    }
    return nil
  }

  func addCurrentFunctionVariableDeclaration(_ vDeclaration: VariableDeclaration) {
    let name = translateIdentifierName(vDeclaration.identifier.name)
    let type = convertType(vDeclaration.type)
    // Declared local expressions don't have assigned expressions
    assert(vDeclaration.assignedExpression == nil)

    addCurrentFunctionVariableDeclaration(BVariableDeclaration(name: name,
                                                               rawName: vDeclaration.identifier.name,
                                                               type: type))
  }

  func addFunctionGlobalVariableReference(referenced: String) {
      if let functionName = getCurrentFunctionName() {
        var modifies = functionReferencedGlobalVariables[functionName] ?? Set<BModifiesDeclaration>()
        modifies.insert(BModifiesDeclaration(variable: referenced))
        functionReferencedGlobalVariables[functionName] = modifies
      }
  }

  func getStructInstanceVariable() -> String {
    let structName = getCurrentTLDName()
    return "nextInstance_\(structName)"
    //print("Could not get struct instance variable, not in a TLD")
    //fatalError()
  }

  func generateStructInstanceVariableName() -> String {
    return "structInstance" // TODO: Generate dynamically?
  }

   func getFunctionParameters(name: String) -> [BParameterDeclaration] {
    if functionParameters[name] == nil {
      functionParameters[name] = []
    }
    return functionParameters[name]!
  }

   func setFunctionParameters(name: String, parameters: [BParameterDeclaration]) {
    functionParameters[name] = parameters
  }

   func getFunctionVariableDeclarations(name: String) -> [BVariableDeclaration] {
    if functionVariableDeclarations[name] == nil {
      functionVariableDeclarations[name] = []
    }
    return functionVariableDeclarations[name]!
  }

   func setFunctionVariableDeclarations(name: String, declarations: [BVariableDeclaration]) {
    functionVariableDeclarations[name] = declarations
  }

   func addCurrentFunctionVariableDeclaration(_ bvDeclaration: BVariableDeclaration) {
    if let functionName = getCurrentFunctionName() {
      var variableDeclarations = getFunctionVariableDeclarations(name: functionName)
      variableDeclarations.append(bvDeclaration)
      setFunctionVariableDeclarations(name: functionName, declarations: variableDeclarations)
    } else {
      print("Error cannot add variable declaration to function: \(bvDeclaration), not currently translating a function")
      fatalError()
    }
  }

   func generateFunctionReturnVariable() -> String {
    if let functionName = getCurrentFunctionName() {
      let returnVariable = generateRandomIdentifier(prefix: "result_variable_\(functionName)_")
      functionReturnVariableName[functionName] = returnVariable
      return returnVariable
    }
    print("Cannot generate function return variable, not currently in a function")
    fatalError()
  }

  func getFunctionReturnVariable() -> String {
    if let functionName = getCurrentFunctionName() {
      if let returnVariable = functionReturnVariableName[functionName] {
        return returnVariable
      }
      print("Could not find return variables for function \(functionName)")
      fatalError()
    }
    print("Could not find return variable not currently in a function")
    fatalError()
  }

   func getFunctionTypes(_ functionCall: FunctionCall,
                                 enclosingType: RawTypeIdentifier?) -> (RawType, [RawType], Bool) {
    let currentType = enclosingType == nil ? getCurrentTLDName() : enclosingType!
    if let scopeContext = getCurrentFunction().scopeContext {
      let callerProtections = getCurrentContractBehaviorDeclaration()?.callerProtections ?? []
      let typeStates = getCurrentContractBehaviorDeclaration()?.states ?? []
      let matchedCall = environment.matchFunctionCall(functionCall,
                                                      enclosingType: currentType,
                                                      typeStates: typeStates,
                                                      callerProtections: callerProtections,
                                                      scopeContext: scopeContext)
      var returnType: RawType
      var parameterTypes: [RawType]
      var isInit: Bool = false
      switch matchedCall {
      case .matchedFunction(let functionInformation):
        returnType = functionInformation.resultType
        parameterTypes = functionInformation.parameterTypes

      case .matchedGlobalFunction(let functionInformation):
        returnType = functionInformation.resultType
        parameterTypes = functionInformation.parameterTypes

      case .matchedFunctionWithoutCaller(let callableInformations):
        //TODO: No idea what this means
        print("Matched function without caller?")
        print(callableInformations)
        fatalError()

      case .matchedInitializer(let specialInformation):
        // Initialisers do not return values -> although struct inits do = ints
        // TODO: Assume only for struct initialisers. Need to implement for contract initialisers/fallback functions?

        // This only works for struct initialisers.
        returnType = .basicType(.int)
        parameterTypes = specialInformation.parameterTypes
        isInit = true

      case .matchedFallback(let specialInformation):
        //TODO: Handle fallback functions
        print("Handle fallback calls")
        print(specialInformation)
        fatalError()

      case .failure(let candidates):
        print("could not find function for call: \(functionCall)")
        print(currentType)
        print(candidates)
        fatalError()
      }

      return (returnType, parameterTypes, isInit)
    }
    print("Cannot get scopeContext from current function")
    fatalError()
  }

   func handleFunctionCall(_ functionCall: FunctionCall,
                                   structInstance: BExpression? = nil,
                                   owningType: String? = nil) -> (BExpression, [BStatement]) {
    let rawFunctionName = functionCall.identifier.name
    var argumentsExpressions = [BExpression]()
    var argumentsStatements = [BStatement]()

    if let instance = structInstance {
      // instance to pass as first argument
      argumentsExpressions.append(instance)
    }
    for arg in functionCall.arguments {
      let (expr, stmts) = process(arg.expression)
      argumentsExpressions.append(expr)
      argumentsStatements += stmts
    }

    switch rawFunctionName {
    // Special case to handle assert functions
    case "assert":
      // assert that assert function call always has one argument
      assert (argumentsExpressions.count == 1)
      let flintLine = functionCall.identifier.sourceLocation.line
      flintProofObligationSourceLocation[flintLine] = functionCall.sourceLocation
      argumentsStatements.append(.assertStatement(BProofObligation(expression: argumentsExpressions[0],
                                                                   mark: flintLine,
                                                                   obligationType: .assertion)))
      return (.nop, argumentsStatements)

    // Handle fatal error case
    case "fatalError":
      argumentsStatements.append(.assume(.boolean(false)))
      return (.nop, argumentsStatements)

    default: break
    }

    // TODO: Assert that contract invariant holds
    // TODO: Need to link the failing assert to the invariant =>
    //  error msg: Can't call function, the contract invariant does not hold at this point
    //argumentsStatements += (tldInvariants[getCurrentTLDName()] ?? []).map({ .assertStatement($0) })

    let (returnType, parameterTypes, isInit) = getFunctionTypes(functionCall, enclosingType: owningType)
    let functionName: String

    if isInit {
      // When calling struct constructors, need to identify this special
      // function call and set the owning type to the Struct
      functionName = translateGlobalIdentifierName("init" + parameterTypes.reduce("", { $0 + $1.name }),
                                                       tld: rawFunctionName)
    } else {
      functionName = translateGlobalIdentifierName(rawFunctionName + parameterTypes.reduce("", { $0 + $1.name }),
                                                       tld: owningType)
    }

    // Add function call to current function's function calls
    if let curFunctionName = getCurrentFunctionName() {
     var functionCalls = functionFunctionCalls[curFunctionName] ?? []
     functionCalls.insert(functionName)
     functionFunctionCalls[curFunctionName] = functionCalls
    }

    if returnType != RawType.basicType(.void) {
      // Function returns a value
      let returnValueVariable = generateRandomIdentifier(prefix: "v_") // Variable to hold return value
      let returnValue = BExpression.identifier(returnValueVariable)
      let functionCall = BStatement.callProcedure([returnValueVariable],
                                                   functionName,
                                                   argumentsExpressions)
      addCurrentFunctionVariableDeclaration(BVariableDeclaration(name: returnValueVariable,
                                                                 rawName: returnValueVariable,
                                                                 type: convertType(returnType)))
      argumentsStatements.append(functionCall)
      return (returnValue, argumentsStatements)
    } else {
      // Function doesn't return a value
      // Can assume can't be called as part of a nested expression,
      // has return type Void
      argumentsStatements.append(.callProcedure([], functionName, argumentsExpressions))
      return (.nop, argumentsStatements)
    }
  }

   func process(_ functionDeclaration: FunctionDeclaration,
                isStructInit: Bool = false) -> BTopLevelDeclaration {
    let currentFunctionName = getCurrentFunctionName()!
    let body = functionDeclaration.body
    let parameters = functionDeclaration.signature.parameters
    let signature = functionDeclaration.signature
    var returnName = signature.resultType == nil ? nil : generateFunctionReturnVariable()
    var returnType = signature.resultType == nil ? nil : convertType(signature.resultType!)

    var bParameters = [BParameterDeclaration]()
    bParameters += parameters.map({x in process(x)})
    setFunctionParameters(name: currentFunctionName, parameters: bParameters)
    var prePostConditions = [BProofObligation]()
    // TODO: Handle += operators and function calls in pre conditions
    for condition in signature.prePostConditions {
      switch condition {
      case .pre(let e):
        prePostConditions.append(BProofObligation(expression: process(e).0,
                                                  mark: e.sourceLocation.line,
                                                  obligationType: .preCondition))
        flintProofObligationSourceLocation[e.sourceLocation.line] = e.sourceLocation
      case .post(let e):
        prePostConditions.append(BProofObligation(expression: process(e).0,
                                                  mark: e.sourceLocation.line,
                                                  obligationType: .postCondition))
        flintProofObligationSourceLocation[e.sourceLocation.line] = e.sourceLocation
      }
    }

    var functionPostAmble = [BStatement]()
    var functionPreAmble = [BStatement]()
    if let cTld = currentTLD {
     switch cTld {
     case .structDeclaration:
      self.structInstanceVariableName = generateStructInstanceVariableName()
      if isStructInit {
        returnType = .int
        returnName = generateFunctionReturnVariable()

        let nextInstance = getStructInstanceVariable()

        addCurrentFunctionVariableDeclaration(BVariableDeclaration(name: self.structInstanceVariableName!,
                                                                   rawName: self.structInstanceVariableName!,
                                                                   type: .int))
        addCurrentFunctionVariableDeclaration(BVariableDeclaration(name: nextInstance,
                                                                   rawName: nextInstance,
                                                                   type: .int))
        let reserveNextStructInstance: [BStatement] = [
          .assignment(.identifier(self.structInstanceVariableName!), .identifier(nextInstance)),
          .assignment(.identifier(nextInstance), .add(.identifier(nextInstance), .integer(1)))
        ]

        let returnAllocatedStructInstance: [BStatement] = [
          .assignment(.identifier(returnName!), .identifier(self.structInstanceVariableName!)),
          .returnStatement
        ]

        let structInitPost: BExpression =
          .lessThan(.identifier(nextInstance), .add(.old(.identifier(nextInstance)), .integer(1)))

        prePostConditions.append(BProofObligation(expression: structInitPost,
                                                  mark: functionDeclaration.sourceLocation.line,
                                                  obligationType: .postCondition))
        flintProofObligationSourceLocation[functionDeclaration.sourceLocation.line] = functionDeclaration.sourceLocation

        functionPreAmble += reserveNextStructInstance
        functionPostAmble += returnAllocatedStructInstance
      } else {
        bParameters.append(BParameterDeclaration(name: self.structInstanceVariableName!,
                                                 rawName: self.structInstanceVariableName!,
                                                 type: .int))
      }
     default: break
      }
    }

    let bStatements = body.flatMap({x in process(x)}) + functionPostAmble

    // Procedure must hold invariant
    let invariants = tldInvariants[getCurrentTLDName()] ?? []
    prePostConditions += invariants

    // About to exit function, reset struct instance variable
    self.structInstanceVariableName = nil

    return .procedureDeclaration(BProcedureDeclaration(
      name: currentFunctionName,
      returnType: returnType,
      returnName: returnName,
      parameters: bParameters,
      prePostConditions: prePostConditions,
      // TODO: Fix, only put the variables actually referenced
      modifies: functionReferencedGlobalVariables.values.reduce(Set<BModifiesDeclaration>(), {$0.union($1)}),
      statements: bStatements,
      variables: getFunctionVariableDeclarations(name: currentFunctionName)
      ))

  }
}
