import AST

import BigInt

extension BoogieTranslator {
  func process(_ statement: Statement, structInvariants: [BIRInvariant] = []) -> [BStatement] {
    switch statement {
    case .expression(let expression):
      // Expresson can return statements -> assignments, or assertions..
      var (bExpression, statements, postStatements) = process(expression, structInvariants: structInvariants)
      switch bExpression {
      case BExpression.identifier, BExpression.mapRead, BExpression.nop:
        break
      default:
        statements.append(.expression(bExpression, TranslationInformation(sourceLocation: expression.sourceLocation)))
      }
      return statements + postStatements

    case .returnStatement(let returnStatement):
      var statements = [BStatement]()
      if let expression = returnStatement.expression {
        let (translatedExpr, preStatements, postStatements) = process(expression, structInvariants: structInvariants)
        statements += preStatements
        statements.append(.assignment(.identifier(getFunctionReturnVariable()),
                                      translatedExpr,
                                      TranslationInformation(sourceLocation: returnStatement.sourceLocation)))
        statements.append(.expression(.identifier("return;"),
                                      TranslationInformation(sourceLocation: returnStatement.sourceLocation)))
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
      return [.assignment(.identifier(stateVariable), .integer(BigUInt(stateValue)),
                          TranslationInformation(sourceLocation: becomeStatement.sourceLocation))]

    case .ifStatement(let ifStatement):
      let (condExpr, condStmt, postCondStmt) = process(ifStatement.condition, structInvariants: structInvariants)
      let oldCtx = setCurrentScopeContext(ifStatement.ifBodyScopeContext)
      let trueCase = ifStatement.body.flatMap({ x in process(x, structInvariants: structInvariants) })
      _ = setCurrentScopeContext(ifStatement.elseBodyScopeContext)
      let falseCase = ifStatement.elseBody.flatMap({ x in process(x, structInvariants: structInvariants) })
      _ = setCurrentScopeContext(oldCtx)
      return condStmt + [
        .ifStatement(BIfStatement(condition: condExpr,
                                  trueCase: trueCase,
                                  falseCase: falseCase,
                                  ti: TranslationInformation(sourceLocation: ifStatement.sourceLocation))
        )] + postCondStmt

    case .forStatement(let forStatement):
      // Set to new For context
      let oldCtx = setCurrentScopeContext(forStatement.forBodyScopeContext)

      let indexName = generateRandomIdentifier(prefix: "loop_index")
      let index = BExpression.identifier(indexName)
      addCurrentFunctionVariableDeclaration(BVariableDeclaration(name: indexName,
                                                                 rawName: indexName,
                                                                 type: .int))
      let incrementIndex = BStatement.assignment(index, .add(index, .integer(BigUInt(1))),
                                                 TranslationInformation(sourceLocation: forStatement.sourceLocation))

      // Create for loop variable
      // Some variable types require shadow variables, eg dictionaries (array of keys)
      let variableName = translateIdentifierName(forStatement.variable.identifier.name)
      let loopVariable = BExpression.identifier(variableName)
      for declaration in generateVariables(forStatement.variable).0 {
        addCurrentFunctionVariableDeclaration(declaration)
      }

      var initialIndexValue: BExpression
      var finalIndexValue: BExpression
      var assignValueToVariable: [BStatement]
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
      let loopVariableType = forStatement.variable.type.rawType

      switch forStatement.iterable {
      case .range(let rangeExpression):
        let (start, startStmts, postStartStmts) = process(rangeExpression.initial, structInvariants: structInvariants)
        let (bound, boundStmts, postEndStmts) = process(rangeExpression.bound, structInvariants: structInvariants)
        preAmbleStmts += startStmts + boundStmts
        postAmbleStmts += postStartStmts + postEndStmts
        // Adjust the index update accordingly
        let inclusive: Bool = rangeExpression.op.kind == .punctuation(.closedRange)
        if inclusive {
          finalIndexValue = BExpression.add(bound, .integer(BigUInt(1)))
        } else {
          finalIndexValue = bound
        }

        assignValueToVariable = [BStatement.assignment(loopVariable, index, TranslationInformation(
            sourceLocation: forStatement.sourceLocation))]
        initialIndexValue = start

      case .arrayLiteral:
        let (iterableIdentifier, iterableStmts, iterablePostStmts) = processIterableLiterals(
            iterable: forStatement.iterable,
            iterableType: iterableType)
        preAmbleStmts += iterableStmts
        postAmbleStmts += iterablePostStmts

        guard case .identifier(let arrayLitIdentifier) = iterableIdentifier else {
          print("unexpected expression result from processIterableLiterals \(iterableIdentifier)")
          fatalError()
        }

        assignValueToVariable = [BStatement.assignment(loopVariable,
                                                       .mapRead(iterableIdentifier, index),
                                                       TranslationInformation(
                                                           sourceLocation: forStatement.sourceLocation))]
        initialIndexValue = BExpression.integer(BigUInt(0))
        finalIndexValue = .identifier(normaliser.getShadowArraySizePrefix(depth: 0) + arrayLitIdentifier)

      case .dictionaryLiteral:
        let (iterableIdentifier, iterableStmts, iterablePostStmts) = processIterableLiterals(
            iterable: forStatement.iterable,
            iterableType: iterableType)
        preAmbleStmts += iterableStmts
        postAmbleStmts += iterablePostStmts

        guard case .identifier(let dictLitIdentifier) = iterableIdentifier else {
          print("unexpected expression result from processIterableLiterals \(iterableIdentifier)")
          fatalError()
        }

        let keysExpr = BExpression.identifier(normaliser.getShadowDictionaryKeysPrefix(depth: 0) + dictLitIdentifier)
        assignValueToVariable = [BStatement.assignment(loopVariable,
                                                       .mapRead(iterableIdentifier,
                                                                .mapRead(keysExpr, index)),
                                                       TranslationInformation(
                                                           sourceLocation: forStatement.sourceLocation))]
        initialIndexValue = BExpression.integer(BigUInt(0))
        finalIndexValue = .identifier(normaliser.getShadowArraySizePrefix(depth: 0) + dictLitIdentifier)

      default:
        // assume identifier used as iterable: type is array -> index into array
        // type of dict -> index into dict keys array

        switch iterableType {
        case .arrayType:
          // Array type - the resulting expression is indexable
          let (indexableExpr, indexableStmts, postIndexableStmts) = process(forStatement.iterable,
                                                                            structInvariants: structInvariants)
          preAmbleStmts += indexableStmts
          postAmbleStmts += postIndexableStmts
          let iterableSize = getIterableSizeExpression(iterable: forStatement.iterable)

          assignValueToVariable = [
            BStatement.assignment(loopVariable,
                                  .mapRead(indexableExpr, index),
                                  TranslationInformation(sourceLocation: forStatement.sourceLocation))
          ]

          initialIndexValue = BExpression.integer(BigUInt(0))
          finalIndexValue = iterableSize

          switch loopVariableType {
          case .dictionaryType: break
          case .arrayType, .fixedSizeArrayType:
            guard case .identifier(let arrayIdentifer) = indexableExpr else {
              print("Currently, only variable multidimensional arrays may work, fatal error")
              fatalError()
            }
            let bStatement = BStatement.assignment(
                .identifier(normaliser.getShadowArraySizePrefix(depth: 0) + variableName),
                .mapRead(.identifier(normaliser.getShadowArraySizePrefix(depth: 1) + arrayIdentifer), index),
                TranslationInformation(sourceLocation: forStatement.sourceLocation)
            )
            assignValueToVariable.append(bStatement)
          default: break
          }

        case .dictionaryType:
          // Dictionary type - iterate through the values of the dict, accessed via it's keys
          let (iterableExpr, iterableStmts, postIterableStmts) = process(forStatement.iterable)
          preAmbleStmts += iterableStmts
          postAmbleStmts += postIterableStmts
          let iterableSize = getIterableSizeExpression(iterable: forStatement.iterable)
          let iterableKeys = getDictionaryKeysExpression(dict: forStatement.iterable)

          assignValueToVariable = [BStatement.assignment(loopVariable,
                                                         .mapRead(iterableExpr, .mapRead(iterableKeys, index)),
                                                         TranslationInformation(
                                                             sourceLocation: forStatement.sourceLocation))]
          initialIndexValue = BExpression.integer(BigUInt(0))
          finalIndexValue = iterableSize

        default:
          print("unknown sequence type used for for-loop iterable \(iterableType)")
          fatalError()
        }
      }

      let assignIndexInitialValue = BStatement.assignment(index,
                                                          initialIndexValue,
                                                          TranslationInformation(
                                                              sourceLocation: forStatement.sourceLocation))

      // - create invariant, which says it's always increasing
      // - use to index into iterable - work out how to index into iterable (helper?)
      // - assign value of iterable[index] to variable name
      // - increment index until length of iterable - work out length of iterable

      let body = assignValueToVariable
      + forStatement.body.flatMap({ process($0) })
      + [incrementIndex]

      // index should be less than finalIndexValue
      let loopInvariantExpression: BExpression = .lessThanOrEqual(index, finalIndexValue)
      //.lessThan(.old(index), index)
      let loopInvariants = [BLoopInvariant(expression: loopInvariantExpression,
                                           ti: TranslationInformation(sourceLocation: forStatement.sourceLocation))
      ]
      // Reset old context
      _ = setCurrentScopeContext(oldCtx)
      return /*condStmt +*/ preAmbleStmts + [assignIndexInitialValue,
                                             .whileStatement(BWhileStatement(
                                                 condition: .lessThan(index, finalIndexValue),
                                                 body: body,
                                                 invariants: loopInvariants,
                                                 ti: TranslationInformation(sourceLocation: forStatement.sourceLocation)
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

      self.enclosingCatchBody = doCatchStatement.catchBody.flatMap({ process($0, structInvariants: structInvariants) })
      self.enclosingDoBody = doCatchStatement.doBody
      while let firstStmt = self.enclosingDoBody.first {
        self.enclosingDoBody.remove(at: 0)
        // Process first
        doCatchStmts += process(firstStmt, structInvariants: structInvariants)
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
               structInvariants: [BIRInvariant] = [],
               structInstanceVariable: BExpression? = nil) -> (BExpression, [BStatement], [BStatement]) {
    switch expression {
    case .variableDeclaration(let variableDeclaration):
      // Some variable types require shadow variables, eg dictionaries (array of keys)
      for declaration in generateVariables(variableDeclaration).0 {
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
        // have to handle error being thrown
        // - assert invariants all hold
        // - get return type of external call
        // - create variable to hold return value
        // - havoc return value
        // - create variable to hold (wasSuccessful)
        // - havoc executionSuccess variable
        // - havoc all global variables + assume invariants (other function calls could have changed their values)
        // if executionSucces -> continue as normal, else -> catchBlock

        var stmts = [BStatement]()
        // Only select 1 half of pre/post invariants
        for invariant in self.tldInvariants.values.flatMap({ $0 }) + self.globalInvariants + structInvariants {
          let ti = TranslationInformation(sourceLocation: externalCall.sourceLocation,
                                          isExternalCall: true,
                                          relatedTI: invariant.ti)
          stmts.append(.assertStatement(BAssertStatement(expression: invariant.expression,
                                                         ti: ti)))
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
        let ti = TranslationInformation(sourceLocation: expression.sourceLocation)
        stmts.append(.havoc(returnValueVariable, ti))
        stmts.append(.havoc(successValueVariable, ti))

        var trueStatements = [BStatement]()
        // Havoc global state - to capture that the values of the global state can be changed,
        for variableName in (self.contractGlobalVariables[getCurrentTLDName()] ?? []) + (
            self.structGlobalVariables[getCurrentTLDName()] ?? []) {
          trueStatements.append(.havoc(variableName, ti))
          // Add external call
        }

        // we can assume that the invariants will hold - as all the functions must hold the invariant
        for invariant in (self.tldInvariants[getCurrentTLDName()] ?? []) + self.globalInvariants + structInvariants {
          trueStatements.append(.assume(invariant.expression, ti))
        }

        if let nextStatement = self.enclosingDoBody.first {
          self.enclosingDoBody.remove(at: 0)
          trueStatements += process(nextStatement)
        }

        let handleExceptionIf = BIfStatement(condition: .identifier(successValueVariable),
                                             trueCase: trueStatements,
                                             falseCase: self.enclosingCatchBody,
                                             ti: ti)

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
      return process(binaryExpression, shadowVariablePrefix: shadowVariablePrefix, isBeingAssignedTo: isBeingAssignedTo)

    case .bracketedExpression(let bracketedExpression):
      return process(bracketedExpression.expression,
                     localContext: localContext,
                     shadowVariablePrefix: shadowVariablePrefix,
                     subscriptDepth: subscriptDepth,
                     structInvariants: structInvariants)

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
      return process(typeConversionExpression.expression, structInvariants: structInvariants)

    case .returnsExpression(let returnsExpression):
      let (returnsExpr, _, _) = process(returnsExpression, structInvariants: structInvariants)
      return (.equals(.identifier(self.getFunctionReturnVariable()), returnsExpr), [], [])

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
                       shadowVariablePrefix: ((Int) -> String)?,
                       isBeingAssignedTo: Bool) -> (BExpression, [BStatement], [BStatement]) {

    let lhs = binaryExpression.lhs
    let rhs = binaryExpression.rhs

    switch binaryExpression.opToken {
    case .dot:
      let (e, preStmts, postStmts) = processDotBinaryExpression(binaryExpression,
                                                                shadowVariablePrefix: shadowVariablePrefix,
                                                                isBeingAssignedTo: isBeingAssignedTo)
      return (e, preStmts, postStmts)
    case .equal:
      let (e, preStmts, postStmts) = handleAssignment(lhs, rhs)
      let context = Context(environment: environment,
                            enclosingType: getCurrentTLDName(),
                            scopeContext: getCurrentScopeContext() ?? ScopeContext())

      let (triggerPreStmts, triggerPostStmts) =
          triggers.lookup(binaryExpression,
                          context,
                          extra: ["lhs_translated_expression": e, "enclosing_function": getCurrentFunction().name]
          ) // TODO: Bad. only works because I know that rn an assignment rule is the only one that could trigger.
      return (e, triggerPreStmts + preStmts, postStmts + triggerPostStmts)
    default: break
    }

    let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
    let (lhsExpr, lhsStmts, postLhsStmts) = process(lhs)
    let preStmts = lhsStmts + rhsStmts
    let postStmts = postRhsStmts + postLhsStmts
    switch binaryExpression.opToken {
    case .plusEqual:
      return (lhsExpr, preStmts + [.assignment(lhsExpr,
                                               .add(lhsExpr, rhsExpr),
                                               TranslationInformation(sourceLocation: binaryExpression.sourceLocation)
      )],
          postStmts)
    case .minusEqual:
      return (lhsExpr, preStmts + [.assignment(lhsExpr,
                                               .subtract(lhsExpr, rhsExpr),
                                               TranslationInformation(sourceLocation: binaryExpression.sourceLocation)
      )],
          postStmts)
    case .timesEqual:
      return (lhsExpr, preStmts + [.assignment(lhsExpr,
                                               .multiply(lhsExpr, rhsExpr),
                                               TranslationInformation(sourceLocation: binaryExpression.sourceLocation)
      )],
          postStmts)
    case .divideEqual:
      // Check for divide-by-zero error
      let ti = TranslationInformation(sourceLocation: rhs.sourceLocation,
                                      isUserDirectCause: false,
                                      failingMsg: ErrorMsg.DivideByZero)
      return (lhsExpr, preStmts + [
        BStatement.assertStatement(BAssertStatement(expression: .not(.equals(rhsExpr, .integer(0))), ti: ti)),
        BStatement.assignment(lhsExpr,
                              .divide(lhsExpr, rhsExpr),
                              TranslationInformation(sourceLocation: binaryExpression.sourceLocation))], postStmts)
    case .plus:
      return (.add(lhsExpr, rhsExpr), preStmts, postStmts)
    case .minus:
      return (.subtract(lhsExpr, rhsExpr), preStmts, postStmts)
    case .times:
      return (.multiply(lhsExpr, rhsExpr), preStmts, postStmts)
    case .divide:
      // Check for divide-by-zero error
      let ti = TranslationInformation(sourceLocation: rhs.sourceLocation,
                                      isUserDirectCause: false,
                                      failingMsg: ErrorMsg.DivideByZero)

      return (.divide(lhsExpr, rhsExpr),
          preStmts + [BStatement.assertStatement(
              BAssertStatement(expression: .not(.equals(rhsExpr, .integer(0))), ti: ti))],
          postStmts)
    case .overflowingPlus:
      return (.modulo(.add(lhsExpr, rhsExpr), .integer(BigUInt(2).power(256))), preStmts, postStmts)
    case .overflowingMinus:
      return (.modulo(.subtract(lhsExpr, rhsExpr), .integer(BigUInt(2).power(256))), preStmts, postStmts)
    case .overflowingTimes:
      return (.modulo(.multiply(lhsExpr, rhsExpr), .integer(BigUInt(2).power(256))), preStmts, postStmts)

    case .power:
      return (.functionApplication("power", [lhsExpr, rhsExpr]), preStmts, postStmts)

        // Comparisons
    case .doubleEqual:
      return (.equals(lhsExpr, rhsExpr), preStmts, postStmts)
    case .notEqual:
      return (.not(.equals(lhsExpr, rhsExpr)), preStmts, postStmts)
    case .openAngledBracket:
      return (.lessThan(lhsExpr, rhsExpr), preStmts, postStmts)
    case .closeAngledBracket:
      return (.greaterThan(lhsExpr, rhsExpr), preStmts, postStmts)
    case .lessThanOrEqual:
      return (.or(.lessThan(lhsExpr, rhsExpr), .equals(lhsExpr, rhsExpr)), preStmts, postStmts)
    case .greaterThanOrEqual:
      return (.not(.lessThan(lhsExpr, rhsExpr)), preStmts, postStmts)
    case .or:
      return (.or(lhsExpr, rhsExpr), preStmts, postStmts)
    case .and:
      return (.and(lhsExpr, rhsExpr), preStmts, postStmts)
    case .implies:
      return (.implies(lhsExpr, rhsExpr), preStmts, postStmts)

    case .percent:
      return (.modulo(lhsExpr, rhsExpr), preStmts, postStmts)

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
    case .arrayType, .fixedSizeArrayType:
      let rhsSizeExpr: BExpression
      if case .arrayLiteral = rhs {
        let (iterableIdentifier, iterableStmts, postIterableStmts) = processIterableLiterals(iterable: rhs,
                                                                                             iterableType: lhsType)
        assignmentStatements += iterableStmts + [.assignment(lhsExpr, iterableIdentifier,
                                                             TranslationInformation(sourceLocation: lhs.sourceLocation)
        )]
        postAmbleStmts += postIterableStmts
        guard case .identifier(let identifier) = iterableIdentifier else {
          print("unexpected expression result from processIterableLiterals \(iterableIdentifier)")
          fatalError()
        }
        rhsSizeExpr = .identifier(normaliser.getShadowArraySizePrefix(depth: 0) + identifier)
      } else {
        // Assignment between two identifiers of sorts
        let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
        assignmentStatements += rhsStmts + [.assignment(lhsExpr, rhsExpr,
                                                        TranslationInformation(sourceLocation: lhs.sourceLocation))]
        rhsSizeExpr = getIterableSizeExpression(iterable: rhs)
        postAmbleStmts += postRhsStmts
      }

      // process shadow variables:
      //  - size
      // Get size shadow variable and set equal to iterableIdentifier size shadowvariable
      let lhsSizeExpr = getIterableSizeExpression(iterable: lhs)
      assignmentStatements.append(
          .assignment(lhsSizeExpr, rhsSizeExpr, TranslationInformation(sourceLocation: lhs.sourceLocation)))

    case .dictionaryType:
      let rhsSizeExpr: BExpression
      let rhsKeysExpr: BExpression
      if case .dictionaryLiteral = rhs {
        let (iterableIdentifier, iterableStmts, postIterableStmts) = processIterableLiterals(iterable: rhs,
                                                                                             iterableType: lhsType)
        assignmentStatements += iterableStmts + [.assignment(lhsExpr, iterableIdentifier,
                                                             TranslationInformation(sourceLocation: lhs.sourceLocation)
        )]
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
        assignmentStatements += rhsStmts + [.assignment(lhsExpr, rhsExpr,
                                                        TranslationInformation(sourceLocation: lhs.sourceLocation))]
        postAmbleStmts += postRhsStmts
        rhsSizeExpr = getIterableSizeExpression(iterable: rhs)
        rhsKeysExpr = getDictionaryKeysExpression(dict: rhs)
      }
      // process shadow variables:
      //  - size
      //  - keys
      // Get size + keys shadow variable and set equal to iterableIdentifier size + keys shadowvariable
      let lhsSizeExpr = getIterableSizeExpression(iterable: lhs)
      let lhsKeysExpr = getDictionaryKeysExpression(dict: lhs)
      assignmentStatements.append(
          .assignment(lhsSizeExpr, rhsSizeExpr, TranslationInformation(sourceLocation: lhs.sourceLocation)))
      assignmentStatements.append(
          .assignment(lhsKeysExpr, rhsKeysExpr, TranslationInformation(sourceLocation: lhs.sourceLocation)))

    default:
      let (rhsExpr, rhsStmts, postRhsStmts) = process(rhs)
      postAmbleStmts += postRhsStmts
      assignmentStatements += rhsStmts + [.assignment(lhsExpr, rhsExpr,
                                                      TranslationInformation(sourceLocation: lhs.sourceLocation))]
    }

    return (lhsExpr, assignmentStatements, postAmbleStmts)
  }

  private func processIterableLiterals(iterable: Expression,
                                       iterableType: RawType) -> (BExpression, [BStatement], [BStatement]) {
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
    case .fixedSizeArrayType(let inner, _): iterableElementType = inner
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
          (bExpr, preStatements, postStmts) = processIterableLiterals(iterable: expression,
                                                                      iterableType: iterableElementType)
        default:
          (bExpr, preStatements, postStmts) = process(expression)
        }

        assignmentStmts += preStatements
        assignmentStmts.append(.assignment(.mapRead(.identifier(literalVariableName), .integer(BigUInt(counter))),
                                           bExpr,
                                           TranslationInformation(sourceLocation: iterable.sourceLocation)))
        postAmbleStmts += postStmts
        counter += 1
      }

      //Shadow variables
      let sizeShadowVariableName = normaliser.getShadowArraySizePrefix(depth: 0) + literalVariableName
      assignmentStmts.append(.assignment(.identifier(sizeShadowVariableName),
                                         .integer(BigUInt(counter)),
                                         TranslationInformation(sourceLocation: iterable.sourceLocation)))

    case .dictionaryLiteral(let dictionaryLiteral):
      var counter = 0
      let keysShadowVariableName = normaliser.getShadowDictionaryKeysPrefix(depth: 0) + literalVariableName
      //assignmentStmts.append(
      //  .assignment(.identifier(keysShadowVariableName), defaultValue(convertType(iterableType))))
      for entry in dictionaryLiteral.elements {
        let (bKeyExpr, bKeyPreStatements, bKeyPostStmts) = process(entry.key)
        let (bValueExpr, bValuePreStatements, bValuePostStmts): (BExpression, [BStatement], [BStatement])
        // See if nested literal
        switch entry.value {
        case .arrayLiteral, .dictionaryLiteral:
          (bValueExpr, bValuePreStatements, bValuePostStmts) = processIterableLiterals(iterable: entry.value,
                                                                                       iterableType: iterableElementType
          )
        default:
          (bValueExpr, bValuePreStatements, bValuePostStmts) = process(entry.value)
        }

        assignmentStmts += bKeyPreStatements
        assignmentStmts += bValuePreStatements
        postAmbleStmts += bValuePostStmts + bKeyPostStmts

        assignmentStmts.append(.assignment(.mapRead(.identifier(literalVariableName), bKeyExpr),
                                           bValueExpr,
                                           TranslationInformation(sourceLocation: iterable.sourceLocation)))

        // Shadow variables
        // Set keys shadow variable to stated dictionary keys
        assignmentStmts.append(.assignment(.mapRead(.identifier(keysShadowVariableName), .integer(BigUInt(counter))),
                                           bKeyExpr,
                                           TranslationInformation(sourceLocation: iterable.sourceLocation)))

        counter += 1
      }

      // Shadow variables
      let sizeShadowVariableName = normaliser.getShadowArraySizePrefix(depth: 0) + literalVariableName
      assignmentStmts.append(.assignment(.identifier(sizeShadowVariableName),
                                         .integer(BigUInt(counter)),
                                         TranslationInformation(sourceLocation: iterable.sourceLocation)))

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
                                          shadowVariablePrefix: ((Int) -> String)?,
                                          isBeingAssignedTo: Bool) -> (BExpression, [BStatement], [BStatement]) {

    let lhs = binaryExpression.lhs
    let rhs = binaryExpression.rhs

    if binaryExpression.isExplicitPropertyAccess {
      // self.A, means get the A in the contract, not the local declaration
      return process(rhs,
                     localContext: false,
                     shadowVariablePrefix: shadowVariablePrefix,
                     isBeingAssignedTo: isBeingAssignedTo)
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
    case .arrayType, .dictionaryType, .fixedSizeArrayType:
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
      print(lhs.sourceLocation)
      fatalError()
    }

    switch rhs {
    case .functionCall(let functionCall):
      let (structInstance, instancePreStmts, instancePostStmts) = process(lhs,
                                                                          isBeingAssignedTo: isBeingAssignedTo,
                                                                          enclosingTLD: enclosingType)
      let (call, callPre, callPost) = self.handleFunctionCall(functionCall,
                                                              structInstance: structInstance,
                                                              owningType: structName)
      return (call, instancePreStmts + callPre, instancePostStmts + callPost)

    case .identifier(let identifier):
      var shadowPrefix: String = ""
      if let prefixFunc = shadowVariablePrefix {
        shadowPrefix = prefixFunc(0)
      }

      let (structExp, structPreStmts, structPostStmts) = process(lhs,
                                                                 isBeingAssignedTo: isBeingAssignedTo,
                                                                 enclosingTLD: enclosingType)
      let field = processIdentifier(identifier,
                                    localContext: false,
                                    shadowVariablePrefix: shadowPrefix,
                                    enclosingTLD: structName,
                                    structInstanceVariable: structExp)
      return (field, structPreStmts, structPostStmts)

    case .subscriptExpression(let subscriptExpression):
      let (structExp, structPreStmts, structPostStmts) = process(lhs,
                                                                 isBeingAssignedTo: isBeingAssignedTo,
                                                                 enclosingTLD: enclosingType)
      let (subExpr, subPreStmts, subPostStmts) = processSubscriptExpression(subscriptExpression,
                                                                            shadowVariablePrefix: shadowVariablePrefix,
                                                                            enclosingTLD: structName,
                                                                            structInstanceVariable: structExp,
                                                                            isBeingAssignedTo: isBeingAssignedTo)
      return (subExpr, structPreStmts + subPreStmts, subPostStmts + structPostStmts)
    default:
      let (structExp, structPreStmts, structPostStmts) = process(lhs,
                                                                 isBeingAssignedTo: isBeingAssignedTo,
                                                                 enclosingTLD: enclosingType)
      let (rhsExpr, rhsPreStmts, rhsPostStmts) = process(rhs,
                                                         localContext: false,
                                                         shadowVariablePrefix: shadowVariablePrefix,
                                                         isBeingAssignedTo: isBeingAssignedTo,
                                                         enclosingTLD: structName)
      return (.mapRead(rhsExpr, structExp), structPreStmts + rhsPreStmts, rhsPostStmts + structPostStmts)
    }
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

    if let caller = self.currentCallerIdentifier, caller.name == identifier.name, identifier.enclosingType == nil {
      return .identifier(translateGlobalIdentifierName("caller"))
    }

    if let returningValue = self.currentFunctionReturningValue, returningValue == identifier.name {
      guard let returnValue = self.currentFunctionReturningValueValue else {
        print("expecting returning value value, but found none")
        fatalError()
      }
      return returnValue
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
                                          isBeingAssignedTo: Bool = false
                                          ) -> (BExpression, [BStatement], [BStatement]) {
    var postAmble = [BStatement]()
    let (subExpr, subStmts, subPostStmts) = process(subscriptExpression.baseExpression,
                                                    localContext: localContext,
                                                    shadowVariablePrefix: shadowVariablePrefix,
                                                    subscriptDepth: subscriptDepth + 1,
                                                    enclosingTLD: enclosingTLD,
                                                    structInstanceVariable: structInstanceVariable)
    var (indxExpr, indexStmts, indexPostStmts) = process(subscriptExpression.indexExpression, localContext: true)
    postAmble += subPostStmts + indexPostStmts
    let sizeShadowVariable = getIterableSizeExpression(iterable: subscriptExpression.baseExpression,
                                                       enclosingTLD: enclosingTLD,
                                                       structInstanceVariable: structInstanceVariable)

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

    if isBeingAssignedTo {
      // - if index is bigger than size (in arrays)
      // - or if key is not in keys
      //  - increment size value + (add to keys, if dict)
      switch baseExpressionType {
      case .arrayType:
        // is index bigger than size?
        postAmble.append(.ifStatement(BIfStatement(condition: .not(.lessThan(indxExpr, sizeShadowVariable)),
                                                   trueCase: [
                                                     // increment size variable
                                                     .assignment(sizeShadowVariable,
                                                                 .add(sizeShadowVariable, .integer(BigUInt(1))),
                                                                 TranslationInformation(
                                                                     sourceLocation: subscriptExpression.sourceLocation)
                                                     )
                                                   ],
                                                   falseCase: [],
                                                   ti: TranslationInformation(
                                                       sourceLocation: subscriptExpression.sourceLocation,
                                                       isUserDirectCause: false))))
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

        let keysShadowVariable = getDictionaryKeysExpression(dict: subscriptExpression.baseExpression,
                                                             enclosingTLD: enclosingTLD,
                                                             structInstanceVariable: structInstanceVariable)

        let checkingContains =
            BWhileStatement(condition: .and(.lessThan(counter, sizeShadowVariable),
                                            .not(containsKey)),
                            body: [
                              .ifStatement(
                                  BIfStatement(
                                      condition: .equals(.mapRead(keysShadowVariable, counter), indxExpr),
                                      trueCase: [.assignment(
                                          containsKey,
                                          .boolean(true),
                                          TranslationInformation(
                                              sourceLocation: subscriptExpression.sourceLocation,
                                              isUserDirectCause: false))],
                                      falseCase: [],
                                      ti: TranslationInformation(
                                          sourceLocation: subscriptExpression.sourceLocation,
                                          isUserDirectCause: false))),
                              .assignment(counter,
                                          .add(counter, .integer(BigUInt(1))),
                                          TranslationInformation(sourceLocation: subscriptExpression.sourceLocation))
                            ],
                            invariants: [],
                            ti: TranslationInformation(sourceLocation: subscriptExpression.sourceLocation))
        let update = BIfStatement(condition: .not(containsKey),
                                  trueCase: [
                                    // add dictionary entry
                                    .assignment(.mapRead(keysShadowVariable, sizeShadowVariable),
                                                indxExpr,
                                                TranslationInformation(
                                                    sourceLocation: subscriptExpression.sourceLocation)),
                                    // increment size variable
                                    .assignment(sizeShadowVariable,
                                                .add(sizeShadowVariable, .integer(BigUInt(1))),
                                                TranslationInformation(
                                                    sourceLocation: subscriptExpression.sourceLocation))
                                  ],
                                  falseCase: [],
                                  ti: TranslationInformation(sourceLocation: subscriptExpression.sourceLocation,
                                                             isUserDirectCause: false))

        postAmble.append(.assignment(counter, .integer(BigUInt(0)),
                                     TranslationInformation(sourceLocation: subscriptExpression.sourceLocation)))
        postAmble.append(.assignment(containsKey, .boolean(false),
                                     TranslationInformation(sourceLocation: subscriptExpression.sourceLocation)))
        postAmble.append(.whileStatement(checkingContains))
        postAmble.append(.ifStatement(update))
      default: break
      }
    }

    // Assert access is lt the size of the array
    // if not isAssignment || fixedSizeArrayType, => indx lessThan size
    // else => indx lessThanOrEqual size
    let fixedArrayType: Bool
    if case .fixedSizeArrayType = baseExpressionType {
      fixedArrayType = true
    } else {
      fixedArrayType = false
    }

    let accessAssertExpression: BExpression
    if !isBeingAssignedTo || fixedArrayType {
      accessAssertExpression = .lessThan(indxExpr, sizeShadowVariable)
    } else {
      accessAssertExpression = .lessThanOrEqual(indxExpr, sizeShadowVariable)
    }
    let ti = TranslationInformation(sourceLocation: subscriptExpression.sourceLocation,
                                    isUserDirectCause: false,
                                    failingMsg: ErrorMsg.ArrayOutofBoundsAccess)
    let assertValidAccess = BStatement.assertStatement(BAssertStatement(expression: accessAssertExpression,
                                                                        ti: ti))
    // Only add assert check, if array type
    switch baseExpressionType {
    case .arrayType, .fixedSizeArrayType:
      indexStmts.append(assertValidAccess)
    default: break
    }

    return (.mapRead(subExpr, indxExpr), subStmts + indexStmts, postAmble)
  }

  private func getIterableSizeExpression(iterable: Expression,
                                         enclosingTLD: String? = nil,
                                         structInstanceVariable: BExpression? = nil) -> BExpression {
    return process(iterable,
                   shadowVariablePrefix: normaliser.getShadowArraySizePrefix,
                   enclosingTLD: enclosingTLD,
                   structInstanceVariable: structInstanceVariable).0
  }

  private func getDictionaryKeysExpression(dict: Expression,
                                           enclosingTLD: String? = nil,
                                           structInstanceVariable: BExpression? = nil) -> BExpression {
    return process(dict,
                   shadowVariablePrefix: normaliser.getShadowDictionaryKeysPrefix,
                   enclosingTLD: enclosingTLD,
                   structInstanceVariable: structInstanceVariable).0
  }
}
