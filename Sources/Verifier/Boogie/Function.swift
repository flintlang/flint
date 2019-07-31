import AST
import Source
import Lexer
import Foundation

import BigInt

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
      return normaliser.getFunctionName(function: behaviourDeclarationMember, tld: getCurrentTLDName())
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

  func generateStructInstanceVariableName() -> String {
    if let functionName = getCurrentFunctionName() {
      let instance = generateRandomIdentifier(prefix: "struct_instance_\(functionName)_")
      return instance
    }
    print("Cannot generate struct instance variable name, not currently in a function")
    fatalError()
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

  func getFunctionVariableDeclarations(name: String) -> Set<BVariableDeclaration> {
    if functionVariableDeclarations[name] == nil {
      functionVariableDeclarations[name] = Set<BVariableDeclaration>()
    }
    return functionVariableDeclarations[name]!
  }

  func setFunctionVariableDeclarations(name: String, declarations: Set<BVariableDeclaration>) {
    functionVariableDeclarations[name] = declarations
  }

  func addCurrentFunctionVariableDeclaration(_ bvDeclaration: BVariableDeclaration) {
    if let functionName = getCurrentFunctionName() {
      var variableDeclarations = getFunctionVariableDeclarations(name: functionName)
      variableDeclarations.insert(bvDeclaration)
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
    if let scopeContext = getCurrentScopeContext() {
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
        print("function - could not find function for call: \(functionCall)")
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
                          owningType: String? = nil) -> (BExpression, [BStatement], [BStatement]) {
    let rawFunctionName = functionCall.identifier.name
    var argumentsExpressions = [BExpression]()
    var argumentsStatements = [BStatement]()
    var argumentPostStmts = [BStatement]()

    // Process triggers
    let context = Context(environment: environment,
                          enclosingType: getCurrentTLDName(),
                          scopeContext: getCurrentScopeContext() ?? ScopeContext())
    let (triggerPreStmts, triggerPostStmts) = triggers.lookup(functionCall, context)

    for arg in functionCall.arguments {
      let (expr, stmts, postStmts) = process(arg.expression)
      argumentsExpressions.append(expr)
      //TODO: Type of array/dict -> add those here
      //TODO if type array/dict return shadow variables - size_0, 1, 2..  + keys
      argumentsStatements += stmts
      argumentPostStmts += postStmts
    }

    // Can be called not in function body
    switch rawFunctionName {
    case "prev":
      self.twoStateContextInvariant = true
      return (.old(argumentsExpressions[0]), argumentsStatements + triggerPreStmts, argumentPostStmts + triggerPostStmts
      )

    case "STATE":
      let stateVariable = getStateVariable()
      let stateValue: Int
      switch functionCall.arguments[0].expression {
      case .identifier(let identifier):
        stateValue = getStateVariableValue(identifier.name)
      default:
        print("Unknown expression in becomeStatement \(functionCall.arguments[0].expression)")
        fatalError()
      }
      return (.equals(.identifier(stateVariable), .integer(BigUInt(stateValue))), argumentsStatements + triggerPreStmts,
          argumentPostStmts + triggerPostStmts)

    case "arrayContains":
      // check array/dict contains values
      // check calls should have 2 arguments:
      assert(argumentsExpressions.count == 2)
      // exists. i: typeof(arg1.keys) :: arg1[i] == arg2

      let (sizeArgExpression, _, _) = process(functionCall.arguments[0].expression,
                                              shadowVariablePrefix: normaliser.getShadowArraySizePrefix)
      return (.quantified(.exists,
                          [BParameterDeclaration(name: "i", rawName: "i", type: .int)],
                          .and(.equals(.mapRead(argumentsExpressions[0], .identifier("i")), argumentsExpressions[1]),
                               .and(.greaterThanOrEqual(.identifier("i"), .integer(0)),
                                    .greaterThan(sizeArgExpression, .identifier("i"))))),
          argumentsStatements + triggerPreStmts, argumentPostStmts + triggerPostStmts)

    case "dictContains":
      // check array/dict contains values
      // check calls should have 2 arguments:
      assert(argumentsExpressions.count == 2)
      // exists. i: typeof(arg1.keys) :: arg1[i] == arg2

      let (sizeArgExpression, _, _) = process(functionCall.arguments[0].expression,
                                              shadowVariablePrefix: normaliser.getShadowArraySizePrefix)
      let (keysArgExpression, _, _) = process(functionCall.arguments[0].expression,
                                              shadowVariablePrefix: normaliser.getShadowDictionaryKeysPrefix)
      return (.quantified(.exists,
                          [BParameterDeclaration(name: "i", rawName: "i", type: .int)],
                          .and(.equals(.mapRead(keysArgExpression, .identifier("i")), argumentsExpressions[1]),
                               .and(.greaterThanOrEqual(.identifier("i"), .integer(0)),
                                    .greaterThan(sizeArgExpression, .identifier("i"))))),
          argumentsStatements + triggerPreStmts, argumentPostStmts + triggerPostStmts)

    case "arrayEach":
      // check that each element of an array, satisfies a property
      // check calls should have 3 arguments:
      assert(argumentsExpressions.count == 3)
      // eachArray(elem, array, property)
      // forall i :: i >= 0 && i < size ==> property[elem/array[i]]

      guard case .identifier(let identifier) = functionCall.arguments[0].expression else {
        print("not an identifier was used for eachArray operator argument expression")
        fatalError()
      }

      self.currentFunctionReturningValue = identifier.name
      self.currentFunctionReturningValueValue = .mapRead(argumentsExpressions[1], .identifier("$i"))

      let (propertyExpression, _, _) = process(functionCall.arguments[2].expression,
                                               shadowVariablePrefix: normaliser.getShadowArraySizePrefix)
      self.currentFunctionReturningValue = nil

      let (sizeArgExpression, _, _) = process(functionCall.arguments[1].expression,
                                              shadowVariablePrefix: normaliser.getShadowArraySizePrefix)
      return (.quantified(.forall,
                          [BParameterDeclaration(name: "$i", rawName: "$i", type: .int)],
                          .implies(.and(.greaterThanOrEqual(.identifier("$i"), .integer(0)),
                                        .greaterThan(sizeArgExpression, .identifier("$i"))),
                                   propertyExpression)),
          argumentsStatements + triggerPreStmts,
          argumentPostStmts + triggerPostStmts)
    case "forall":
      assert(argumentsExpressions.count == 3)
      let variableArgument: FunctionArgument = functionCall.arguments[0]
      let typeArgument: FunctionArgument = functionCall.arguments[0]

      guard case .identifier(let variable) = variableArgument.expression,
            case .identifier(let type) = typeArgument.expression else {
        print("forall must be introduced with a typed variable declaration, for some t of type T: `t, T`")
        fatalError()
      }
      self.currentFunctionReturningValue = variable.name
      self.currentFunctionReturningValueValue = currentFunctionReturningValue.map { name in
        return .identifier(name)
      }
      let (propertyExpression, _, _) = process(functionCall.arguments[2].expression,
                                               shadowVariablePrefix: normaliser.getShadowArraySizePrefix)

      let btype = convertType(
           AST.Type(identifier: AST.Identifier(name: type.name, sourceLocation: typeArgument.sourceLocation)))

      return (.quantified(.forall,
                          [BParameterDeclaration(name: variable.name, rawName: variable.name, type: btype)],
                          propertyExpression), [], [])
    case "exists":
      assert(argumentsExpressions.count == 3)
      let variableArgument: FunctionArgument = functionCall.arguments[0]
      let typeArgument: FunctionArgument = functionCall.arguments[0]

      guard case .identifier(let variable) = variableArgument.expression,
            case .identifier(let type) = typeArgument.expression else {
        print("exists must be introduced with a typed variable declaration, for some t of type T: `t, T`")
        fatalError()
      }
      self.currentFunctionReturningValue = variable.name
      self.currentFunctionReturningValueValue = currentFunctionReturningValue.map { name in
        return .identifier(name)
      }
      let (propertyExpression, _, _) = process(functionCall.arguments[2].expression,
                                               shadowVariablePrefix: normaliser.getShadowArraySizePrefix)

      let btype = convertType(
          AST.Type(identifier: AST.Identifier(name: type.name, sourceLocation: typeArgument.sourceLocation)))

      return (.quantified(.exists,
                          [BParameterDeclaration(name: variable.name, rawName: variable.name, type: btype)],
                          propertyExpression), [], [])
    default: break
    }

    guard let currentFunctionName = getCurrentFunctionName() else {
      print("Unable to get current function name - while processing function call")
      fatalError()
    }

    // Can only be called from within a function
    switch rawFunctionName {
        // Special case to handle assert functions
    case "assert":
      // assert that assert function call always has one argument
      assert(argumentsExpressions.count == 1)
      argumentsStatements.append(.assertStatement(BAssertStatement(expression: argumentsExpressions[0],
                                                                   ti: TranslationInformation(
                                                                       sourceLocation: functionCall.sourceLocation))))
      return (.nop, argumentsStatements + triggerPreStmts, argumentPostStmts + triggerPostStmts)

        // Handle fatal error case
    case "fatalError":
      argumentsStatements.append(
          .assume(.boolean(false), TranslationInformation(sourceLocation: functionCall.sourceLocation)))
      return (.nop, argumentsStatements + triggerPreStmts, argumentPostStmts + triggerPostStmts)

    case "send":
      // send calls should have 2 arguments:
      // send(account, &w)
      assert(argumentsExpressions.count == 2)

      // Is an external call -> assert contract invariants hold
      var stmts = [BStatement]()
      // Only select 1 half of pre/post invariants
      for invariant in self.tldInvariants.values.flatMap({ $0 }) + self.globalInvariants + self.structInvariants {
        let ti = TranslationInformation(sourceLocation: functionCall.sourceLocation,
                                        isExternalCall: true,
                                        relatedTI: invariant.ti)
        stmts.append(.assertStatement(BAssertStatement(expression: invariant.expression,
                                                       ti: ti)))
      }

      // Need to havoc global state - could be re-entered
      let ti = TranslationInformation(sourceLocation: functionCall.sourceLocation)
      var trueStatements = [BStatement]()
      // Havoc global state - to capture that the values of the global state can be changed,
      for variableName in (self.contractGlobalVariables[getCurrentTLDName()] ?? []) + (
          self.structGlobalVariables[getCurrentTLDName()] ?? []) {
        trueStatements.append(.havoc(variableName, ti))
        // Add external call
      }

      // we can assume that the invariants will hold - as all the functions must hold the invariant
      for invariant in (self.tldInvariants[getCurrentTLDName()] ?? []) + self.globalInvariants + self.structInvariants {
        trueStatements.append(.assume(invariant.expression, ti))
      }

      let procedureName = "send"
      // Call Boogie send function
      let functionCall = BStatement.callProcedure(BCallProcedure(returnedValues: [],
                                                                 procedureName: procedureName,
                                                                 arguments: argumentsExpressions,
                                                                 ti: TranslationInformation(
                                                                     sourceLocation: functionCall.sourceLocation)))

      // Add procedure call to callGraph
      addProcedureCall(currentFunctionName, procedureName)
      return (.nop, triggerPreStmts + stmts + [functionCall] + trueStatements, argumentPostStmts + triggerPostStmts)

    case "returning":
      //returning(returnvalue, property over return value)
      assert(argumentsExpressions.count == 2)
      guard case .identifier(let identifier) = functionCall.arguments[0].expression else {
        print("not an identifier was used for returning operator argument expression")
        fatalError()
      }
      self.currentFunctionReturningValue = identifier.name
      self.currentFunctionReturningValueValue = .identifier(self.functionReturnVariableName[getCurrentFunctionName()!]!)

      let (expr, _, _) = process(functionCall.arguments[1].expression)

      self.currentFunctionReturningValue = nil

      return (expr, argumentsStatements + triggerPreStmts, argumentPostStmts + triggerPostStmts)

    default:
      // Check if a trait 'initialiser' is being called
      if environment.isTraitDeclared(rawFunctionName) {
        // Is being called, so return dummy value - ignore the init, doesn't do anything
        return (.integer(0), [], [])
      }
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
      functionName = normaliser.translateGlobalIdentifierName("init" + normaliser.flattenTypes(types: parameterTypes),
                                                              tld: rawFunctionName)
    } else {
      functionName = normaliser.translateGlobalIdentifierName(
          rawFunctionName + normaliser.flattenTypes(types: parameterTypes),
          tld: owningType ?? getCurrentTLDName())
    }

    if let instance = structInstance, !isInit {
      // instance to pass as first argument
      argumentsExpressions.insert(instance, at: 0)
    }

    if returnType != RawType.basicType(.void) {
      // Function returns a value
      let returnValueVariable = generateRandomIdentifier(prefix: "v_") // Variable to hold return value
      let returnValue = BExpression.identifier(returnValueVariable)
      let functionCall = BStatement.callProcedure(BCallProcedure(returnedValues: [returnValueVariable],
                                                                 procedureName: functionName,
                                                                 arguments: argumentsExpressions,
                                                                 ti: TranslationInformation(
                                                                     sourceLocation: functionCall.sourceLocation)))
      addCurrentFunctionVariableDeclaration(BVariableDeclaration(name: returnValueVariable,
                                                                 rawName: returnValueVariable,
                                                                 type: convertType(returnType)))
      argumentsStatements.append(functionCall)
      // Add procedure call to callGraph
      addProcedureCall(currentFunctionName, functionName)
      return (returnValue, argumentsStatements + triggerPreStmts, triggerPostStmts)
    } else {
      // Function doesn't return a value
      // Can assume can't be called as part of a nested expression,
      // has return type Void
      argumentsStatements.append(.callProcedure(BCallProcedure(returnedValues: [],
                                                               procedureName: functionName,
                                                               arguments: argumentsExpressions,
                                                               ti: TranslationInformation(
                                                                   sourceLocation: functionCall.sourceLocation))))
      // Add procedure call to callGraph
      addProcedureCall(currentFunctionName, functionName)
      return (.nop, argumentsStatements + triggerPreStmts, argumentPostStmts + triggerPostStmts)
    }
  }

  private func getIterableTypeDepth(type: RawType, depth: Int = 0) -> Int {
    switch type {
    case .arrayType(let type): return getIterableTypeDepth(type: type, depth: depth + 1)
    case .dictionaryType(_, let valueType): return getIterableTypeDepth(type: valueType, depth: depth + 1)
    case .fixedSizeArrayType(let type, _): return getIterableTypeDepth(type: type, depth: depth + 1)
    default:
      return depth
    }
  }

  func process(_ functionDeclaration: FunctionDeclaration,
               isStructInit: Bool = false,
               isContractInit: Bool = false,
               callerProtections: [CallerProtection] = [],
               callerBinding: Identifier? = nil,
               structInvariants: [BIRInvariant] = [],
               typeStates: [TypeState] = []
  ) -> BIRTopLevelDeclaration {
    let currentFunctionName = getCurrentFunctionName()!
    let body = functionDeclaration.body
    let parameters = functionDeclaration.signature.parameters
    var signature = functionDeclaration.signature
    var returnName = signature.resultType == nil ? nil : generateFunctionReturnVariable()
    var returnType = signature.resultType == nil ? nil : convertType(signature.resultType!)
    let oldCtx = setCurrentScopeContext(functionDeclaration.scopeContext)

    let callers = callerProtections.filter({ !$0.isAny }).map({ $0.identifier })

    // Process caller capabilities
    // Need the caller preStatements to handle the case when a function is called
    let (callerPreConds, callerPreStatements) = processCallerCapabilities(callers, callerBinding)

    // Process type states
    let typeStatePreConds = processTypeStates(typeStates)

    // Process triggers
    let context = Context(environment: environment,
                          enclosingType: getCurrentTLDName(),
                          scopeContext: getCurrentScopeContext() ?? ScopeContext())
    let (triggerPreStmts, triggerPostStmts) = triggers.lookup(functionDeclaration, context)

    var functionPostAmble = [BStatement]()
    var functionPreAmble = [BStatement]()

    var modifies = [String]()
    var preConditions = [BPreCondition]()
    var postConditions = [BPostCondition]()
    var bParameters = [BParameterDeclaration]()
    for param in parameters {
      let (bParam, paramPreConditions, initStatements, modifiesStrings) = processParameter(param)
      functionPreAmble += initStatements
      preConditions += paramPreConditions
      bParameters += bParam
      modifies += modifiesStrings
    }
    if let cTld = currentTLD {
      switch cTld {
      case .structDeclaration:
        self.structInstanceVariableName = generateStructInstanceVariableName()
        if isStructInit {
          returnType = .int
          returnName = generateFunctionReturnVariable()

          let nextInstance = normaliser.generateStructInstanceVariable(structName: getCurrentTLDName())

          addCurrentFunctionVariableDeclaration(BVariableDeclaration(name: self.structInstanceVariableName!,
                                                                     rawName: self.structInstanceVariableName!,
                                                                     type: .int))
          let reserveNextStructInstance: [BStatement] = [
            .assignment(.identifier(self.structInstanceVariableName!),
                        .identifier(nextInstance),
                        TranslationInformation(sourceLocation: functionDeclaration.sourceLocation)),
            .assignment(.identifier(nextInstance),
                        .add(.identifier(nextInstance), .integer(1)),
                        TranslationInformation(sourceLocation: functionDeclaration.sourceLocation))
          ]
          // Include nextInstance in modifies
          var nextInstanceId = Identifier(name: "nextInstance", //TODO: Work out how to get raw name
                                          sourceLocation: functionDeclaration.sourceLocation)
          nextInstanceId.enclosingType = getCurrentTLDName()
          signature.mutates.append(nextInstanceId)

          let returnAllocatedStructInstance: [BStatement] = [
            .assignment(.identifier(returnName!),
                        .identifier(self.structInstanceVariableName!),
                        TranslationInformation(sourceLocation: functionDeclaration.sourceLocation))
            //.returnStatement
          ]

          let structInitPost: BExpression =
              .equals(.identifier(nextInstance), .add(.old(.identifier(nextInstance)), .integer(1)))

          postConditions.append(BPostCondition(expression: structInitPost,
                                               ti: TranslationInformation(
                                                   sourceLocation: functionDeclaration.sourceLocation)))

          functionPreAmble += reserveNextStructInstance
          functionPostAmble += returnAllocatedStructInstance
        } else {
          bParameters.insert(BParameterDeclaration(name: self.structInstanceVariableName!,
                                                   rawName: self.structInstanceVariableName!,
                                                   type: .int), at: 0)
          preConditions.append(BPreCondition(expression: .and(.lessThan(.identifier(self.structInstanceVariableName!),
                                                                        .identifier(
                                                                            normaliser.generateStructInstanceVariable(
                                                                                structName: getCurrentTLDName()))),
                                                              .greaterThanOrEqual(
                                                                  .identifier(self.structInstanceVariableName!),
                                                                  .integer(0))),
                                             ti: TranslationInformation(
                                                 sourceLocation: functionDeclaration.sourceLocation),
                                             free: false))
        }
      default: break
      }
    }
    setFunctionParameters(name: currentFunctionName, parameters: bParameters)

    // TODO: Handle += operators and function calls in pre conditions
    for condition in signature.prePostConditions {
      switch condition {
      case .pre(let e):
        preConditions.append(BPreCondition(expression: process(e).0,
                                           ti: TranslationInformation(sourceLocation: e.sourceLocation)))
      case .post(let e):
        postConditions.append(BPostCondition(expression: process(e).0,
                                             ti: TranslationInformation(sourceLocation: e.sourceLocation)))
      }
    }

    if isContractInit || isStructInit {
      var assignments = [BStatement]()

      for (name, expression) in (tldConstructorInitialisations[getCurrentTLDName()] ?? []) {
        let (e, pre, post) = process(expression)
        assignments += pre
        if isStructInit {
          assignments.append(.assignment(.mapRead(.identifier(name),
                                                  .identifier(self.structInstanceVariableName!)),
                                         e, TranslationInformation(sourceLocation: expression.sourceLocation)))
        } else {
          assignments.append(
              .assignment(.identifier(name), e, TranslationInformation(sourceLocation: expression.sourceLocation)))
        }
        assignments += post
      }
      functionPostAmble += assignments
    }

    // Procedure must hold contract invariants
    let contractInvariants = (tldInvariants[getCurrentTLDName()] ?? [])

    let bStatements = functionIterableSizeAssumptions
    + functionPreAmble
    + body.flatMap({ x in process(x, structInvariants: structInvariants) })
    + functionPostAmble

    // Get mutates from function clause, or from environment if the function was made from a trait
    for mutates in functionDeclaration.mutates + (self.traitFunctionMutates[currentFunctionName] ?? []) {
      let enclosingType = mutates.enclosingType ?? getCurrentTLDName()
      let variableType = environment.type(of: mutates.name, enclosingType: enclosingType)
      switch variableType {
      case .arrayType, .dictionaryType:
        let depthMax = getIterableTypeDepth(type: variableType)
        for depth in 0..<depthMax {
          modifies.append(
              normaliser.getShadowArraySizePrefix(depth: depth)
                  + normaliser.translateGlobalIdentifierName(mutates.name, tld: enclosingType))
          if case .dictionaryType = variableType {
            modifies.append(
                normaliser.getShadowDictionaryKeysPrefix(depth: depth)
                    + normaliser.translateGlobalIdentifierName(mutates.name, tld: enclosingType))
          }
        }
      default:
        break
      }

      modifies.append(normaliser.translateGlobalIdentifierName(mutates.name, tld: enclosingType))
    }

    if isContractInit {
      modifies += contractGlobalVariables[getCurrentTLDName()] ?? []
    }

    if isStructInit {
      modifies += structGlobalVariables[getCurrentTLDName()] ?? []
    }

    let modifiesClauses = Set<BIRModifiesDeclaration>(modifies.map({
      BIRModifiesDeclaration(variable: $0, userDefined: true)
    }))
        // Get the global shadow variables, the function modifies
        // (but can't be directly expressed by the user) - ie. nextInstance_struct
        .union((functionModifiesShadow[currentFunctionName] ?? []).map({
          BIRModifiesDeclaration(variable: $0, userDefined: false)
        }))

    // About to exit function, reset struct instance variable
    self.structInstanceVariableName = nil
    _ = setCurrentScopeContext(oldCtx)

    let returnTypes = returnType == nil ? nil : [returnType!]
    let returnNames = returnName == nil ? nil : [returnName!]
    let procDecl = BIRProcedureDeclaration(
        name: currentFunctionName,
        returnTypes: returnTypes,
        returnNames: returnNames,
        parameters: bParameters,
        preConditions: callerPreConds + (!isContractInit ? typeStatePreConds : []) + preConditions,
        //Inits should establish
        postConditions: postConditions,
        structInvariants: structInvariants,
        contractInvariants: contractInvariants,
        globalInvariants: self.globalInvariants,
        modifies: modifiesClauses,
        statements: callerPreStatements + triggerPreStmts + bStatements + triggerPostStmts,
        variables: getFunctionVariableDeclarations(name: currentFunctionName),
        inline: true, // !functionDeclaration.isPublic,
        ti: TranslationInformation(sourceLocation: functionDeclaration.sourceLocation),
        isHolisticProcedure: false,
        isStructInit: isStructInit,
        isContractInit: isContractInit
    )

    self.functionMapping[currentFunctionName] = procDecl
    return .procedureDeclaration(procDecl)
  }
}
