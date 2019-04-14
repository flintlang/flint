import AST

extension BoogieTranslator {
   func process(_ statement: Statement) -> [BStatement] {
    switch statement {
    case .expression(let expression):
      // Expresson can return statements -> assignments, or assertions..
      var (bExpression, statements, postStatements) = process(expression)
      switch bExpression {
      case BExpression.identifier, BExpression.mapRead, BExpression.nop:
        break
      default:
        statements.append(.expression(bExpression, registerProofObligation(expression.sourceLocation)))
      }
      return statements + postStatements

    case .returnStatement(let returnStatement):
      var statements = [BStatement]()
      if let expression = returnStatement.expression {
        let (translatedExpr, preStatements, postStatements) = process(expression)
        statements += preStatements
        statements.append(.assignment(.identifier(getFunctionReturnVariable()),
                                      translatedExpr,
                                      registerProofObligation(returnStatement.sourceLocation)))
        statements += postStatements
      }
      return statements

    case .becomeStatement(let becomeStatement):
      let stateVariable = getStateVariable()
      let stateValue: Int
      switch becomeStatement.expression {
      case .identifier(let identifier):
         stateValue = getStateVariableValue(identifier.name)
      default:
        print("Unknown expression in becomeStatement \(becomeStatement.expression)")
        fatalError()
      }
      return [.assignment(.identifier(stateVariable), .integer(stateValue), registerProofObligation(becomeStatement.sourceLocation))]

    case .ifStatement(let ifStatement):
      let (condExpr, condStmt, postCondStmt) = process(ifStatement.condition)
      let oldCtx = setCurrentScopeContext(ifStatement.ifBodyScopeContext)
      let trueCase = ifStatement.body.flatMap({x in process(x)})
      _ = setCurrentScopeContext(ifStatement.elseBodyScopeContext)
      let falseCase = ifStatement.elseBody.flatMap({x in process(x)})
      _ = setCurrentScopeContext(oldCtx)
      return condStmt + [
        .ifStatement(BIfStatement(condition: condExpr,
                                  trueCase: trueCase,
                                  falseCase: falseCase,
                                  mark: registerProofObligation(ifStatement.sourceLocation))
        )] + postCondStmt

    case .forStatement(let forStatement):
      // Set to new For context
      let oldCtx = setCurrentScopeContext(forStatement.forBodyScopeContext)

      let indexName = generateRandomIdentifier(prefix: "loop_index")
      let index = BExpression.identifier(indexName)
      addCurrentFunctionVariableDeclaration(BVariableDeclaration(name: indexName,
                                                                 rawName: indexName,
                                                                 type: .int))
      let incrementIndex = BStatement.assignment(index, .add(index, .integer(1)),
                                                 registerProofObligation(forStatement.sourceLocation))

      // Create for loop variable
      // Some variable types require shadow variables, eg dictionaries (array of keys)
      let variableName = translateIdentifierName(forStatement.variable.identifier.name)
      let loopVariable = BExpression.identifier(variableName)
      for declaration in generateVariables(forStatement.variable) {
        addCurrentFunctionVariableDeclaration(declaration)
      }

      var initialIndexValue: BExpression
      var finalIndexValue: BExpression
      var assignValueToVariable: BStatement
      // Statements required for the setup of the condition
      //var condStmts: BStatement

      // if type of iterable is:
      //  - range
      //    - index starts at range start, finish at range finish
      //    - assign value of index
      //  - array
      //    - directly index into array, until array size
      //  - dict
      //    - iterate through values of dict
      //    - shadow keys array

      var preAmbleStmts = [BStatement]()
      var postAmbleStmts = [BStatement]()
      guard let scopeContext = getCurrentScopeContext() else {
        print("no scope context exists when determining type of loop iterable")
        fatalError()
      }
      let iterableType = environment.type(of: forStatement.iterable,
                                          enclosingType: getCurrentTLDName(),
                                          scopeContext: scopeContext)

      switch forStatement.iterable {
      case .range(let rangeExpression):
        let (start, startStmts, postStartStmts) = process(rangeExpression.initial)
        let (bound, boundStmts, postEndStmts) = process(rangeExpression.bound)
        preAmbleStmts += startStmts + boundStmts
        postAmbleStmts += postStartStmts + postEndStmts
        // Adjust the index update accordingly
        let inclusive: Bool = rangeExpression.op.kind == .punctuation(.closedRange)
        if inclusive {
          finalIndexValue = BExpression.add(bound, .integer(1))
        } else {
          finalIndexValue = bound
        }

        assignValueToVariable = BStatement.assignment(loopVariable, index, registerProofObligation(forStatement.sourceLocation))
        initialIndexValue = start

      case .arrayLiteral:
        let (iterableIdentifier, iterableStmts, iterablePostStmts) = processIterableLiterals(iterable: forStatement.iterable,
                                                                                             iterableType: iterableType)
        preAmbleStmts += iterableStmts
        postAmbleStmts += iterablePostStmts

        guard case .identifier(let arrayLitIdentifier) = iterableIdentifier else {
          print("unexpected expression result from processIterableLiterals \(iterableIdentifier)")
          fatalError()
        }

        assignValueToVariable = BStatement.assignment(loopVariable,
                                                      .mapRead(iterableIdentifier, index),
                                                      registerProofObligation(forStatement.sourceLocation))
        initialIndexValue = BExpression.integer(0)
        finalIndexValue = .identifier(normaliser.getShadowArraySizePrefix(depth: 0) + arrayLitIdentifier)

      case .dictionaryLiteral:
        let (iterableIdentifier, iterableStmts, iterablePostStmts) = processIterableLiterals(iterable: forStatement.iterable,
                                                                                             iterableType: iterableType)
        preAmbleStmts += iterableStmts
        postAmbleStmts += iterablePostStmts

        guard case .identifier(let dictLitIdentifier) = iterableIdentifier else {
          print("unexpected expression result from processIterableLiterals \(iterableIdentifier)")
          fatalError()
        }

        let keysExpr = BExpression.identifier(normaliser.getShadowDictionaryKeysPrefix(depth: 0) + dictLitIdentifier)
        assignValueToVariable = BStatement.assignment(loopVariable,
                                                      .mapRead(iterableIdentifier,
                                                               .mapRead(keysExpr, index)),
                                                      registerProofObligation(forStatement.sourceLocation))
        initialIndexValue = BExpression.integer(0)
        finalIndexValue = .identifier(normaliser.getShadowArraySizePrefix(depth: 0) + dictLitIdentifier)

      default:
        // assume identifier used as iterable: type is array -> index into array
        // type of dict -> index into dict keys array

        switch iterableType {
        case .arrayType:
          // Array type - the resulting expression is indexable
          let (indexableExpr, indexableStmts, postIndexableStmts) = process(forStatement.iterable)
          preAmbleStmts += indexableStmts
          postAmbleStmts += postIndexableStmts
          let iterableSize = getIterableSizeExpression(iterable: forStatement.iterable)

          assignValueToVariable = BStatement.assignment(loopVariable,
                                                        .mapRead(indexableExpr, index),
                                                        registerProofObligation(forStatement.sourceLocation))
          initialIndexValue = BExpression.integer(0)
          finalIndexValue = iterableSize

        case .dictionaryType:
          // Dictionary type - iterate through the values of the dict, accessed via it's keys
          let (iterableExpr, iterableStmts, postIterableStmts) = process(forStatement.iterable)
          preAmbleStmts += iterableStmts
          postAmbleStmts += postIterableStmts
          let iterableSize = getIterableSizeExpression(iterable: forStatement.iterable)
          let iterableKeys = getDictionaryKeysExpression(dict: forStatement.iterable)

          assignValueToVariable = BStatement.assignment(loopVariable,
                                                        .mapRead(iterableExpr, .mapRead(iterableKeys, index)),
                                                        registerProofObligation(forStatement.sourceLocation))
          initialIndexValue = BExpression.integer(0)
          finalIndexValue = iterableSize

        default:
          print("unknown sequence type used for for-loop iterable \(iterableType)")
          fatalError()
        }
      }

      let assignIndexInitialValue = BStatement.assignment(index,
                                                          initialIndexValue,
                                                          registerProofObligation(forStatement.sourceLocation))

      // - create invariant, which says it's always increasing
      // - use to index into iterable - work out how to index into iterable (helper?)
      // - assign value of iterable[index] to variable name
      // - increment index until length of iterable - work out length of iterable

      let body = [assignValueToVariable]
               + forStatement.body.flatMap({ process($0) })
               + [incrementIndex]

      // index should be less than finalIndexValue
      let loopInvariantExpression: BExpression = .or(.lessThan(index, finalIndexValue), .equals(index, finalIndexValue))
      //.lessThan(.old(index), index)
      let loopInvariants = [BProofObligation(expression: loopInvariantExpression,
                                             mark: registerProofObligation(forStatement.sourceLocation),
                                             obligationType: .loopInvariant)
                           ]
      // Reset old context
      _ = setCurrentScopeContext(oldCtx)
      return /*condStmt +*/ preAmbleStmts + [assignIndexInitialValue,
        .whileStatement(BWhileStatement(
          condition: .lessThan(index, finalIndexValue),
          body: body,
          invariants: loopInvariants,
          mark: registerProofObligation(forStatement.sourceLocation)
        )
        )] + postAmbleStmts

    case .emitStatement:
      // Ignore emit statements
      return []

    case .doCatchStatement(let doCatchStatement):
      var doCatchStmts = [BStatement]()

      // Handle nested doCatch
      let oldEnclosingCatchBody = self.enclosingCatchBody
      let oldEnclosingDoBody = self.enclosingDoBody

      self.enclosingCatchBody = doCatchStatement.catchBody.flatMap({ process($0) })
      self.enclosingDoBody = doCatchStatement.doBody
      while let firstStmt = self.enclosingDoBody.first {
        self.enclosingDoBody.remove(at: 0)
        // Process first
        doCatchStmts += process(firstStmt)
      }
      self.enclosingCatchBody = oldEnclosingCatchBody
      self.enclosingDoBody = oldEnclosingDoBody

      return doCatchStmts
    }
  }

  func process(_ expression: Expression,
               localContext: Bool = true,
               shadowVariablePrefix: ((Int) -> String)? = nil,
               subscriptDepth: Int = 0,
               isBeingAssignedTo: Bool = false,
               enclosingTLD: String? = nil,
               structInstanceVariable: BExpression? = nil) -> (BExpression, [BStatement], [BStatement]) {
    switch expression {
    case .variableDeclaration(let variableDeclaration):
      // Some variable types require shadow variables, eg dictionaries (array of keys)
      for declaration in generateVariables(variableDeclaration) {
        addCurrentFunctionVariableDeclaration(declaration)
      }
      let shadowVariablePrefix = shadowVariablePrefix ?? { x in return "" }
      return (processIdentifier(variableDeclaration.identifier,
                                localContext: localContext,
                                shadowVariablePrefix: shadowVariablePrefix(subscriptDepth)), [], [])

    case .functionCall(let functionCall):
      let structInstance = structInstanceVariable ?? (self.structInstanceVariableName == nil ? nil :
                                  .identifier(self.structInstanceVariableName!))
      return handleFunctionCall(functionCall, structInstance: structInstance)

    case .externalCall(let externalCall):
      switch externalCall.mode {
      case .normal:
        //TODO: Finish
        // have to handle error being thrown
        // - assert invariants all hold
        // - get return type of external call
        // - create variable to hold return value
        // - havoc return value
        // - create variable to hold (wasSuccessful)
        // - havoc executionSuccess variable
        // if executionSucces -> continue as normal, else -> catchBlock

        var stmts = [BStatement]()
        // Only select 1 half of pre/post invariants
        let tldInvariants = self.tldInvariants.values.flatMap({ $0 }).filter({ $0.obligationType.isPreCondition })
        for invariant in tldInvariants {
          stmts.append(.assertStatement(BProofObligation(expression: invariant.expression,
                                                         mark: invariant.mark,
                                                         obligationType: .assertion)))
        }

        guard let scopeContext = getCurrentScopeContext() else {
          print("couldn't get scope context of current function - used for updating shadow variable")
          fatalError()
        }
        let callerProtections = getCurrentContractBehaviorDeclaration()?.callerProtections ?? []
        let typeStates = getCurrentContractBehaviorDeclaration()?.states ?? []
        let currentType = getCurrentTLDName()
        let functionCallType = environment.type(of: .binaryExpression(externalCall.functionCall),
                                                enclosingType: currentType,
                                                typeStates: typeStates,
                                                callerProtections: callerProtections,
                                                scopeContext: scopeContext)

        let boogieType = convertType(functionCallType)
        let returnValueVariable = generateRandomIdentifier(prefix: "extern_value_") // Variable to hold return value
        addCurrentFunctionVariableDeclaration(BVariableDeclaration(name: returnValueVariable,
                                                                   rawName: returnValueVariable,
                                                                   type: boogieType))

        // Variable to hold is external call completed
        let successValueVariable = generateRandomIdentifier(prefix: "extern_sucess_")
        addCurrentFunctionVariableDeclaration(BVariableDeclaration(name: successValueVariable,
                                                                   rawName: successValueVariable,
                                                                   type: .boolean))
        stmts.append(.havoc(returnValueVariable, registerProofObligation(expression.sourceLocation)))
        stmts.append(.havoc(successValueVariable, registerProofObligation(expression.sourceLocation)))

        var trueStatements = [BStatement]()
        if let nextStatement = self.enclosingDoBody.first {
          self.enclosingDoBody.remove(at: 0)
          trueStatements += process(nextStatement)
        }

        let handleExceptionIf = BIfStatement(condition: .identifier(successValueVariable),
                                             trueCase: trueStatements,
                                             falseCase: self.enclosingCatchBody,
                                             mark: registerProofObligation(expression.sourceLocation))

        stmts.append(.ifStatement(handleExceptionIf))
        return (.identifier(returnValueVariable), stmts, [])

      case .returnsGracefullyOptional:
        // no errors,
        print("TODO: Implement - Cannot translate external call (optional return)")
        fatalError()

      case .isForced:
        // Very similar to normal, except if the external one fails, then just - assume false (revert contract)
        print("TODO: Implement isForced external call")
        fatalError()
      }

    case .identifier(let identifier):
      let shadowVariablePrefix = shadowVariablePrefix ?? { x in return "" }
      return (processIdentifier(identifier,
                                localContext: localContext,
                                shadowVariablePrefix: shadowVariablePrefix(subscriptDepth),
                                enclosingTLD: enclosingTLD,
                                structInstanceVariable: structInstanceVariable), [], [])

    case .binaryExpression(let binaryExpression):
      return process(binaryExpression, shadowVariablePrefix: shadowVariablePrefix)

    case .bracketedExpression(let bracketedExpression):
      return process(bracketedExpression.expression,
                     localContext: localContext,
                     shadowVariablePrefix: shadowVariablePrefix,
                     subscriptDepth: subscriptDepth)

    case .subscriptExpression(let subscriptExpression):
      return processSubscriptExpression(subscriptExpression,
                                        shadowVariablePrefix: shadowVariablePrefix,
                                        enclosingTLD: enclosingTLD,
                                        structInstanceVariable: structInstanceVariable,
                                        subscriptDepth: subscriptDepth,
                                        localContext: localContext,
                                        isBeingAssignedTo: isBeingAssignedTo)

    case .literal(let token):
      return (process(token), [], [])

    case .inoutExpression(let inoutExpression):
      return process(inoutExpression.expression) // TODO: Consider cases where we need to do pass by reference

    case .rawAssembly:
      print("Not implemented translating raw assembly")
      fatalError()

    case .`self`:
      return (.nop, [], [])

    case .typeConversionExpression(let typeConversionExpression):
      //TODO: Handle as? / as! ...
      return process(typeConversionExpression.expression)

    // Assumption - can only be used as iterables in for-loops
    //case .range(let rangeExpression):

      // TODO: Implement expressions
    /*
    case .attemptExpression(let attemptExpression):
    case .sequence(let expressions: [Expression]):
      */

    default:
      print("Not implemented translating \(expression)")
      fatalError()
    }
  }

  private func process(_ binaryExpression: BinaryExpression,
                       // Function which generates shadow variable prefix for variable name, (given a depth)
                       shadowVariablePrefix: ((Int) -> String)?) -> (BExpression, [BStatement], [BStatement]) {
    let lhs = binaryExpression.lhs
    let rhs = binaryExpression.rhs

    switch binaryExpression.opToken {
    case .dot:
      return processDotBinaryExpression(binaryExpression, shadowVariablePrefix: shadowVariablePrefix)
    case .equal:
      return handleAssignment(lhs, rhs)
    case .plusEqual:
      let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts, postLhsStmts) = process(lhs)
      return (lhsExpr, lhsStmts + rhsStmts + [.assignment(lhsExpr,
                                              .add(lhsExpr, rhsExpr),
                                              registerProofObligation(binaryExpression.sourceLocation))],
             postRhsStmts + postLhsStmts)
    case .minusEqual:
      let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts, postLhsStmts) = process(lhs)
      return (lhsExpr, lhsStmts + rhsStmts + [.assignment(lhsExpr,
                                              .subtract(lhsExpr, rhsExpr),
                                              registerProofObligation(binaryExpression.sourceLocation))],
             postRhsStmts + postLhsStmts)
    case .timesEqual:
      let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts, postLhsStmts) = process(lhs)
      return (lhsExpr, lhsStmts + rhsStmts + [.assignment(lhsExpr,
                                              .multiply(lhsExpr, rhsExpr),
                                              registerProofObligation(binaryExpression.sourceLocation))],
              postRhsStmts + postLhsStmts)
    case .divideEqual:
      let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts, postLhsStmts) = process(lhs)
      return (lhsExpr, lhsStmts + rhsStmts + [.assignment(lhsExpr,
                                              .divide(lhsExpr, rhsExpr),
                                              registerProofObligation(binaryExpression.sourceLocation))],
              postRhsStmts + postLhsStmts)
    case .plus:
      let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts, postLhsStmts) = process(lhs)
      return (.add(lhsExpr, rhsExpr), lhsStmts + rhsStmts, postRhsStmts + postLhsStmts)
    case .minus:
      let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts, postLhsStmts) = process(lhs)
      return (.subtract(lhsExpr, rhsExpr), lhsStmts + rhsStmts, postRhsStmts + postLhsStmts)
    case .times:
      let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts, postLhsStmts) = process(lhs)
      return (.multiply(lhsExpr, rhsExpr), lhsStmts + rhsStmts, postRhsStmts + postLhsStmts)
    case .divide:
      let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts, postLhsStmts) = process(lhs)
      return (.divide(lhsExpr, rhsExpr), lhsStmts + rhsStmts, postRhsStmts + postLhsStmts)

    //TODO Handle unsafe operators
    //case .overflowingPlus:
    //case .overflowingMinus:
    //case .overflowingTimes:

    //TODO: Handle power operator
    //case .power:

    // Comparisons
    case .doubleEqual:
      let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts, postLhsStmts) = process(lhs)
      return (.equals(lhsExpr, rhsExpr), lhsStmts + rhsStmts, postRhsStmts + postLhsStmts)
    case .notEqual:
      let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts, postLhsStmts) = process(lhs)
      return (.not(.equals(lhsExpr, rhsExpr)), lhsStmts + rhsStmts, postRhsStmts + postLhsStmts)
    case .openAngledBracket:
      let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts, postLhsStmts) = process(lhs)
      return (.lessThan(lhsExpr, rhsExpr), lhsStmts + rhsStmts, postRhsStmts + postLhsStmts)
    case .closeAngledBracket:
      let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts, postLhsStmts) = process(lhs)
      return (.greaterThan(lhsExpr, rhsExpr), lhsStmts + rhsStmts, postRhsStmts + postLhsStmts)
    case .lessThanOrEqual:
      let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts, postLhsStmts) = process(lhs)
      return (.or(.lessThan(lhsExpr, rhsExpr), .equals(lhsExpr, rhsExpr)), lhsStmts + rhsStmts, postRhsStmts + postLhsStmts)
    case .greaterThanOrEqual:
      let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts, postLhsStmts) = process(lhs)
      return (.not(.lessThan(lhsExpr, rhsExpr)), lhsStmts + rhsStmts, postRhsStmts + postLhsStmts)
    case .or:
      let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts, postLhsStmts) = process(lhs)
      return (.or(lhsExpr, rhsExpr), lhsStmts + rhsStmts, postRhsStmts + postLhsStmts)
    case .and:
      let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts, postLhsStmts) = process(lhs)
      return (.and(lhsExpr, rhsExpr), lhsStmts + rhsStmts, postRhsStmts + postLhsStmts)

    case .percent:
      let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts, postLhsStmts) = process(lhs)
      return (.modulo(lhsExpr, rhsExpr), lhsStmts + rhsStmts, postRhsStmts + postLhsStmts)

      /*
      //TODO: Handle
    case .at:
    case .arrow:
    case .leftArrow:
    case .comma:
    case .semicolon:
    case .doubleSlash:
    case .dotdot:
    case .ampersand:
    case .bang:
    case .question:

    // Ranges
    case .halfOpenRange:
    case .closedRange:
      */
    default:
      print("Unknown binary operator used \(binaryExpression.opToken)")
      fatalError()
    }
  }

  private func handleAssignment(_ lhs: Expression, _ rhs: Expression) -> (BExpression, [BStatement], [BStatement]) {
    // For getting type: array dict...
    let currentType = getCurrentTLDName()
    guard let scopeContext = getCurrentScopeContext() else {
      print("couldn't get scope context of current function - used to determine if accessing struct property")
      fatalError()
    }
    let callerProtections = getCurrentContractBehaviorDeclaration()?.callerProtections ?? []
    let typeStates = getCurrentContractBehaviorDeclaration()?.states ?? []
    let lhsType = environment.type(of: lhs, //TODO: rhs has type of any - need to handle
                                   enclosingType: currentType,
                                   typeStates: typeStates,
                                   callerProtections: callerProtections,
                                   scopeContext: scopeContext)

    var assignmentStatements = [BStatement]()
    var postAmbleStmts = [BStatement]()

    let (lhsExpr, lhsStmts, postLhsStmts) = process(lhs, isBeingAssignedTo: true)
    assignmentStatements += lhsStmts
    postAmbleStmts += postLhsStmts
    switch lhsType {
    case .arrayType:
      let rhsSizeExpr: BExpression
      if case .arrayLiteral = rhs {
        let (iterableIdentifier, iterableStmts, postIterableStmts) = processIterableLiterals(iterable: rhs, iterableType: lhsType)
        assignmentStatements += iterableStmts + [.assignment(lhsExpr, iterableIdentifier, registerProofObligation(lhs.sourceLocation))]
        postAmbleStmts += postIterableStmts
        guard case .identifier(let identifier) = iterableIdentifier else {
          print("unexpected expression result from processIterableLiterals \(iterableIdentifier)")
          fatalError()
        }
        rhsSizeExpr = .identifier(normaliser.getShadowArraySizePrefix(depth: 0) + identifier)
      } else {
        // Assignment between two identifiers of sorts
        let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
        assignmentStatements += rhsStmts + [.assignment(lhsExpr, rhsExpr, registerProofObligation(lhs.sourceLocation))]
        rhsSizeExpr =  getIterableSizeExpression(iterable: rhs)
        postAmbleStmts += postRhsStmts
      }

      // process shadow variables:
      //  - size
      // Get size shadow variable and set equal to iterableIdentifier size shadowvariable
      let lhsSizeExpr =  getIterableSizeExpression(iterable: lhs)
      assignmentStatements.append(.assignment(lhsSizeExpr, rhsSizeExpr, registerProofObligation(lhs.sourceLocation)))

    case .dictionaryType:
      let rhsSizeExpr: BExpression
      let rhsKeysExpr: BExpression
      if case .dictionaryLiteral = rhs {
        let (iterableIdentifier, iterableStmts, postIterableStmts) = processIterableLiterals(iterable: rhs, iterableType: lhsType)
        assignmentStatements += iterableStmts + [.assignment(lhsExpr, iterableIdentifier, registerProofObligation(lhs.sourceLocation))]
        postAmbleStmts += postIterableStmts
        guard case .identifier(let identifier) = iterableIdentifier else {
          print("unexpected expression result from processIterableLiterals \(iterableIdentifier)")
          fatalError()
        }
        rhsSizeExpr = .identifier(normaliser.getShadowArraySizePrefix(depth: 0) + identifier)
        rhsKeysExpr = .identifier(normaliser.getShadowDictionaryKeysPrefix(depth: 0) + identifier)
      } else {
        // Assignment between two identifiers of sorts
        let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
        assignmentStatements += rhsStmts + [.assignment(lhsExpr, rhsExpr, registerProofObligation(lhs.sourceLocation))]
        postAmbleStmts += postRhsStmts
        rhsSizeExpr =  getIterableSizeExpression(iterable: rhs)
        rhsKeysExpr =  getDictionaryKeysExpression(dict: rhs)
      }
      // process shadow variables:
      //  - size
      //  - keys
      // Get size + keys shadow variable and set equal to iterableIdentifier size + keys shadowvariable
      let lhsSizeExpr =  getIterableSizeExpression(iterable: lhs)
      let lhsKeysExpr =  getDictionaryKeysExpression(dict: lhs)
      assignmentStatements.append(.assignment(lhsSizeExpr, rhsSizeExpr, registerProofObligation(lhs.sourceLocation)))
      assignmentStatements.append(.assignment(lhsKeysExpr, rhsKeysExpr, registerProofObligation(lhs.sourceLocation)))

    default:
      let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
      postAmbleStmts += postRhsStmts
      assignmentStatements += rhsStmts + [.assignment(lhsExpr, rhsExpr, registerProofObligation(lhs.sourceLocation))]
    }

    return (lhsExpr, assignmentStatements, postAmbleStmts)
  }

  private func processIterableLiterals(iterable: Expression, iterableType: RawType) -> (BExpression, [BStatement], [BStatement]) {
    let literalVariableName = generateRandomIdentifier(prefix: "lit_")
    addCurrentFunctionVariableDeclaration(BVariableDeclaration(name: literalVariableName,
                                                               rawName: literalVariableName,
                                                               type: convertType(iterableType)))

    for shadowVariableDecl in generateIterableShadowVariables(name: literalVariableName, type: iterableType) {
      addCurrentFunctionVariableDeclaration(shadowVariableDecl)
    }

    let iterableElementType: RawType
    switch iterableType {
    case .arrayType(let inner): iterableElementType = inner
    case .dictionaryType(_, let keyType): iterableElementType = keyType
    default: iterableElementType = iterableType
    }

    var assignmentStmts = [BStatement]()
    var postAmbleStmts = [BStatement]()
    switch iterable {
    case .arrayLiteral(let arrayLiteral):
      var counter = 0
      for expression in arrayLiteral.elements {
        let (bExpr, preStatements, postStmts): (BExpression, [BStatement], [BStatement])
        // See if nested literal
        switch expression {
        case .arrayLiteral, .dictionaryLiteral:
          (bExpr, preStatements, postStmts) = processIterableLiterals(iterable: expression, iterableType: iterableElementType)
        default:
          (bExpr, preStatements, postStmts) = process(expression)
        }

        assignmentStmts += preStatements
        assignmentStmts.append(.assignment(.mapRead(.identifier(literalVariableName), .integer(counter)),
                                           bExpr,
                                           registerProofObligation(iterable.sourceLocation)))
        postAmbleStmts += postStmts
        counter += 1
      }

      //Shadow variables
      let sizeShadowVariableName = normaliser.getShadowArraySizePrefix(depth: 0) + literalVariableName
        assignmentStmts.append(.assignment(.identifier(sizeShadowVariableName),
                                           .integer(counter),
                                           registerProofObligation(iterable.sourceLocation)))

    case .dictionaryLiteral(let dictionaryLiteral):
      var counter = 0
      let keysShadowVariableName = normaliser.getShadowDictionaryKeysPrefix(depth: 0) + literalVariableName
      //assignmentStmts.append(.assignment(.identifier(keysShadowVariableName), defaultValue(convertType(iterableType))))
      for entry in dictionaryLiteral.elements {
        let (bKeyExpr, bKeyPreStatements, bKeyPostStmts) = process(entry.key)
        let (bValueExpr, bValuePreStatements, bValuePostStmts): (BExpression, [BStatement], [BStatement])
        // See if nested literal
        switch entry.value {
        case .arrayLiteral, .dictionaryLiteral:
          (bValueExpr, bValuePreStatements, bValuePostStmts) = processIterableLiterals(iterable: entry.value,
                                                                      iterableType: iterableElementType)
        default:
          (bValueExpr, bValuePreStatements, bValuePostStmts) = process(entry.value)
        }

        assignmentStmts += bKeyPreStatements
        assignmentStmts += bValuePreStatements
        postAmbleStmts += bValuePostStmts + bKeyPostStmts

        assignmentStmts.append(.assignment(.mapRead(.identifier(literalVariableName), bKeyExpr),
                                           bValueExpr,
                                           registerProofObligation(iterable.sourceLocation)))

        // Shadow variables
        // Set keys shadow variable to stated dictionary keys
        assignmentStmts.append(.assignment(.mapRead(.identifier(keysShadowVariableName), .integer(counter)),
                                           bKeyExpr,
                                           registerProofObligation(iterable.sourceLocation)))

        counter += 1
      }

      // Shadow variables
      let sizeShadowVariableName = normaliser.getShadowArraySizePrefix(depth: 0) + literalVariableName
      assignmentStmts.append(.assignment(.identifier(sizeShadowVariableName),
                                         .integer(counter),
                                         registerProofObligation(iterable.sourceLocation)))

    default:
      print("unable to process iterable literal - not an iterable!: \(iterable)")
      fatalError()
    }

    return (.identifier(literalVariableName), assignmentStmts, postAmbleStmts)
  }

  private func processDotBinaryExpression(_ binaryExpression: BinaryExpression,
                                          enclosingType: String? = nil,
                                          // For when accessing size/keys
                                          structInstance: BExpression? = nil,
                                          shadowVariablePrefix: ((Int) -> String)?) -> (BExpression, [BStatement], [BStatement]) {

    let lhs = binaryExpression.lhs
    let rhs = binaryExpression.rhs

    if binaryExpression.isExplicitPropertyAccess {
      // self.A, means get the A in the contract, not the local declaration
      return process(rhs, localContext: false, shadowVariablePrefix: shadowVariablePrefix)
    }

    // For struct fields and methods (eg array size..)
    let currentType = enclosingType ?? getCurrentTLDName()
    let scopeContext = getCurrentScopeContext() ?? ScopeContext()
    let callerProtections = getCurrentContractBehaviorDeclaration()?.callerProtections ?? []
    let typeStates = getCurrentContractBehaviorDeclaration()?.states ?? []
    let lhsType = environment.type(of: lhs,
                                   enclosingType: currentType,
                                   typeStates: typeStates,
                                   callerProtections: callerProtections,
                                   scopeContext: scopeContext)

    // Are we trying to access size/keys properties of arrays/dicts
    switch lhsType {
    case .arrayType, .dictionaryType:
      // Check if trying to access .size or .keys fields or arrays/dictionaries
      switch rhs {
      case .identifier(let identifier) where identifier.name == "size":
        // process lhs, to extract the identifier name, and turn into size_...

        // Process the variable we are finding the size of
        return process(lhs,
                       shadowVariablePrefix: normaliser.getShadowArraySizePrefix,
                       enclosingTLD: enclosingType)

      case .identifier(let identifier) where identifier.name == "keys":
        // process lhs, to extract the identifier name, and turn into keys_...
        // If you've been asked for size shadow variable, you should return that -> to get size of the keys
        if let shadowPrefix = shadowVariablePrefix {
          // Process the variable we are finding the size of
          return process(lhs,
                         shadowVariablePrefix: shadowPrefix,
                         enclosingTLD: enclosingType)
        } else {
          return process(lhs,
                         shadowVariablePrefix: normaliser.getShadowDictionaryKeysPrefix,
                         enclosingTLD: enclosingType)
        }
      default: break
      }
    default:
      break
    }

    // Search for enums + identifiers
    switch lhs {
    case .identifier(let lIdentifier):
      if enums.contains(lIdentifier.name) {
        switch rhs {
        case .identifier(let rIdentifier):
          // TODO:
          return (.identifier(normaliser.translateGlobalIdentifierName(rIdentifier.name, tld: lIdentifier.name)),
                  [], [])
        default:
          break
        }
      }
    default:
      break
    }

    // Accessing property or function of UDT
    guard case .userDefinedType(let structName) = lhsType else {
      print("Not accessing property of a struct: \(lhsType)")
      fatalError()
    }

    switch rhs {
    case .functionCall(let functionCall):
      let (structInstance, instancePreStmts, instancePostStmts) = process(lhs,
                                                                          enclosingTLD: structName)
      let (call, callPre, callPost) = self.handleFunctionCall(functionCall,
                                                              structInstance: structInstance,
                                                              owningType: structName)
      return (call, instancePreStmts + callPre, instancePostStmts + callPost)

    case .identifier(let identifier):
      var shadowPrefix: String = ""
      if let prefixFunc = shadowVariablePrefix {
        shadowPrefix = prefixFunc(0)
      }

      let (structExp, structPreStmts, structPostStmts) = process(lhs, enclosingTLD: enclosingType)
      let field = processIdentifier(identifier,
                                    localContext: false,
                                    shadowVariablePrefix: shadowPrefix,
                                    enclosingTLD: structName,
                                    structInstanceVariable: structExp)
      return (field, structPreStmts, structPostStmts)

    case .subscriptExpression(let subscriptExpression):
      let (structExp, structPreStmts, structPostStmts) = process(lhs, enclosingTLD: enclosingType)
      let (subExpr, subPreStmts, subPostStmts) = processSubscriptExpression(subscriptExpression,
                                                                            shadowVariablePrefix: shadowVariablePrefix,
                                                                            enclosingTLD: structName,
                                                                            structInstanceVariable: structExp)
      return (subExpr, structPreStmts + subPreStmts, subPostStmts + structPostStmts)
    default: break
    }

    print("Unknown type used with `dot` operator \(lhsType)")
    print("\(lhs)")
    print("\(rhs)")
    fatalError()
  }

  // process Identifier
  // localContext: whether we are processing from within a function
  // shadowVariablePrefix: the prefix to use when resolving the identifier name, to get correct shadow variable
  private func processIdentifier(_ identifier: Identifier,
                                 localContext: Bool = true,
                                 shadowVariablePrefix: String = "",
                                 enclosingTLD: String? = nil,
                                 structInstanceVariable: BExpression? = nil) -> BExpression {
    // See if identifier is a local variable
    if localContext,
       let currentFunctionName = getCurrentFunctionName(),
       getFunctionVariableDeclarations(name: currentFunctionName)
         .filter({ $0.rawName == identifier.name })
         .count > 0 ||
        getFunctionParameters(name: currentFunctionName)
         .filter({ $0.rawName == identifier.name })
         .count > 0 {

      return .identifier(shadowVariablePrefix + translateIdentifierName(identifier.name))
    }
    let translatedIdentifier = shadowVariablePrefix + translateGlobalIdentifierName(identifier.name,
                                                                                    enclosingTLD: enclosingTLD)

    if let instanceVariable = structInstanceVariable {
      // Accessing a field in a struct
      return .mapRead(.identifier(translatedIdentifier), instanceVariable)
    } else if let currentStructInstanceVariable = structInstanceVariableName {
      // Currently in a struct, referring to a 'global' variable
      return .mapRead(.identifier(translatedIdentifier),
                       .identifier(currentStructInstanceVariable))
    }
    return .identifier(translatedIdentifier)
  }

  private func processSubscriptExpression(_ subscriptExpression: SubscriptExpression,
                                          shadowVariablePrefix: ((Int) -> String)? = nil,
                                          enclosingTLD: String? = nil,
                                          structInstanceVariable: BExpression? = nil,
                                          subscriptDepth: Int = 0,
                                          localContext: Bool = true,
                                          isBeingAssignedTo: Bool = false) -> (BExpression, [BStatement], [BStatement]) {
    var postAmble = [BStatement]()
    let (subExpr, subStmts, subPostStmts) = process(subscriptExpression.baseExpression,
                                                    localContext: localContext,
                                                    shadowVariablePrefix: shadowVariablePrefix,
                                                    subscriptDepth: subscriptDepth + 1,
                                                    enclosingTLD: enclosingTLD,
                                                    structInstanceVariable: structInstanceVariable)
    let (indxExpr, indexStmts, indexPostStmts) = process(subscriptExpression.indexExpression, localContext: true)
    postAmble += subPostStmts + indexPostStmts
    if isBeingAssignedTo {
      // - if index is bigger than size (in arrays)
      // - or if key is not in keys
      //  - increment size value + (add to keys, if dict)
      let currentType = getCurrentTLDName()
      guard let scopeContext = getCurrentScopeContext() else {
        print("couldn't get scope context of current function - used for updating shadow variable")
        fatalError()
      }
      let callerProtections = getCurrentContractBehaviorDeclaration()?.callerProtections ?? []
      let typeStates = getCurrentContractBehaviorDeclaration()?.states ?? []
      let baseExpressionType = environment.type(of: subscriptExpression.baseExpression,
                                                enclosingType: currentType,
                                                typeStates: typeStates,
                                                callerProtections: callerProtections,
                                                scopeContext: scopeContext)
      switch baseExpressionType {
      case .arrayType:
        // is index bigger than size?
        let sizeShadowVariable = getIterableSizeExpression(iterable: subscriptExpression.baseExpression)
        postAmble.append(.ifStatement(BIfStatement(condition: .not(.lessThan(indxExpr, sizeShadowVariable)),
                                                   trueCase: [
                                                     // increment size variable
                                                     .assignment(sizeShadowVariable,
                                                                 .add(sizeShadowVariable, .integer(1)),
                                                                 registerProofObligation(subscriptExpression.sourceLocation)
                                                                 )
                                                   ],
                                                   falseCase: [],
                                                   mark: registerProofObligation(subscriptExpression.sourceLocation))))
      case .dictionaryType:
        // does keys contain key? - if so, add it!
        //counter = 0
        //containsKey = false
        //while (counter < size && !containsKey) {
        //  if keys[counter] == indxExpr {
        //    containsKeys = true
        //  }
        //  counter += 1
        //}
        //if !containsKey {
        //  keys[size] = indxExpr
        //  size += 1
        //}

        let counterName = generateRandomIdentifier(prefix: "lit_")
        let counter = BExpression.identifier(counterName)
        addCurrentFunctionVariableDeclaration(BVariableDeclaration(name: counterName,
                                                                   rawName: counterName,
                                                                   type: .int))
        let containsKeyName = generateRandomIdentifier(prefix: "lit_")
        let containsKey = BExpression.identifier(containsKeyName)
        addCurrentFunctionVariableDeclaration(BVariableDeclaration(name: containsKeyName,
                                                                   rawName: containsKeyName,
                                                                   type: .boolean))

        let sizeShadowVariable = getIterableSizeExpression(iterable: subscriptExpression.baseExpression)
        let keysShadowVariable = getDictionaryKeysExpression(dict: subscriptExpression.baseExpression)

        let checkingContains =
          BWhileStatement(condition: .and(.lessThan(counter, sizeShadowVariable),
                                          .not(containsKey)),
                          body: [
                            .ifStatement(BIfStatement(condition: .equals(.mapRead(keysShadowVariable, counter),
                                                                         indxExpr),
                                                      trueCase: [.assignment(containsKey,
                                                                 .boolean(true),
                                                                 registerProofObligation(subscriptExpression.sourceLocation))],
                                                      falseCase: [],
                                                      mark: registerProofObligation(subscriptExpression.sourceLocation))),
                            .assignment(counter,
                                        .add(counter, .integer(1)),
                                        registerProofObligation(subscriptExpression.sourceLocation))
                          ],
                          invariants: [],
                          mark: registerProofObligation(subscriptExpression.sourceLocation))
        let update = BIfStatement(condition: .not(containsKey),
                                  trueCase: [
                                    // increment size variable
                                    .assignment(sizeShadowVariable,
                                                .add(sizeShadowVariable, .integer(1)),
                                                registerProofObligation(subscriptExpression.sourceLocation))
                                  ],
                                  falseCase: [],
                                  mark: registerProofObligation(subscriptExpression.sourceLocation))

        postAmble.append(.assignment(counter, .integer(0), registerProofObligation(subscriptExpression.sourceLocation)))
        postAmble.append(.assignment(containsKey, .boolean(false), registerProofObligation(subscriptExpression.sourceLocation)))
        postAmble.append(.whileStatement(checkingContains))
        postAmble.append(.ifStatement(update))
      default: break
      }
    }
    return (.mapRead(subExpr, indxExpr), subStmts + indexStmts, postAmble)
  }

  private func getIterableSizeExpression(iterable: Expression) -> BExpression {
    return process(iterable, shadowVariablePrefix: normaliser.getShadowArraySizePrefix).0
  }

  private func getDictionaryKeysExpression(dict: Expression) -> BExpression {
    return process(dict, shadowVariablePrefix: normaliser.getShadowDictionaryKeysPrefix).0
  }
}
