import AST

extension BoogieTranslator {
   func process(_ statement: Statement) -> [BStatement] {
    switch statement {
    case .expression(let expression):
      // Expresson can return statements -> assignments, or assertions..
      var (bExpression, statements) = process(expression)
      switch bExpression {
      case BExpression.identifier, BExpression.mapRead, BExpression.nop:
        break
      default:
        statements.append(.expression(bExpression))
      }
      return statements

    case .returnStatement(let returnStatement):
      var statements = [BStatement]()
      if let expression = returnStatement.expression {
        let (translatedExpr, preStatements) = process(expression)
        statements += preStatements
        statements.append(.assignment(.identifier(getFunctionReturnVariable()),
                                      translatedExpr))
      }
      statements.append(.returnStatement)
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
      return [.assignment(.identifier(stateVariable), .integer(stateValue))]

    case .ifStatement(let ifStatement):
      let (condExpr, condStmt) = process(ifStatement.condition)
      let oldCtx = setCurrentScopeContext(ifStatement.ifBodyScopeContext)
      let trueCase = ifStatement.body.flatMap({x in process(x)})
      _ = setCurrentScopeContext(ifStatement.elseBodyScopeContext)
      let falseCase = ifStatement.elseBody.flatMap({x in process(x)})
      _ = setCurrentScopeContext(oldCtx)
      return condStmt + [
        .ifStatement(BIfStatement(condition: condExpr,
                                  trueCase: trueCase,
                                  falseCase: falseCase)
        )]

    case .forStatement(let forStatement):
      // Set to new For context
      let oldCtx = setCurrentScopeContext(forStatement.forBodyScopeContext)

      let indexName = generateRandomIdentifier(prefix: "loop_index")
      let index = BExpression.identifier(indexName)
      addCurrentFunctionVariableDeclaration(BVariableDeclaration(name: indexName,
                                                                 rawName: indexName,
                                                                 type: .int))
      let incrementIndex = BStatement.assignment(index, .add(index, .integer(1)))

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

      switch forStatement.iterable {
      case .range(let rangeExpression):
        let (start, _) = process(rangeExpression.initial)
        let (bound, _) = process(rangeExpression.bound)
        // Adjust the index update accordingly
        let inclusive: Bool = rangeExpression.op.kind == .punctuation(.closedRange)
        if inclusive {
          finalIndexValue = BExpression.add(bound, .integer(1))
        } else {
          finalIndexValue = bound
        }

        assignValueToVariable = BStatement.assignment(loopVariable, index)
        initialIndexValue = start

      default:
        // assume type is array -> index into array
        // type of dict -> index into dict keys array

        guard let scopeContext = getCurrentScopeContext() else {
          print("no scope context exists when determining type of loop iterable")
          fatalError()
        }

        let iterableType = environment.type(of: forStatement.iterable,
                                            enclosingType: getCurrentTLDName(),
                                            scopeContext: scopeContext)

        switch iterableType {
        case .arrayType:
          // Array type - the resulting expression is indexable
          let (iterableExpr, _) = process(forStatement.iterable)
          let iterableSize = getIterableSizeExpression(iterable: forStatement.iterable)

          assignValueToVariable = BStatement.assignment(loopVariable, .mapRead(iterableExpr, index))
          initialIndexValue = BExpression.integer(0)
          finalIndexValue = iterableSize

        case .dictionaryType:
          // Dictionary type - iterate through the values of the dict, accessed via it's keys
          let (iterableExpr, _) = process(forStatement.iterable)
          let iterableSize = getIterableSizeExpression(iterable: forStatement.iterable)

          assignValueToVariable = BStatement.assignment(loopVariable, .mapRead(iterableExpr, index))
          initialIndexValue = BExpression.integer(0)
          finalIndexValue = iterableSize

        default:
          print("unknown sequence type used for for-loop iterable \(iterableType)")
          fatalError()
        }

      }

      let assignIndexInitialValue = BStatement.assignment(index, initialIndexValue)

      // - create invariant, which says it's always increasing
      // - use to index into iterable - work out how to index into iterable (helper?)
      // - assign value of iterable[index] to variable name
      // - increment index until length of iterable - work out length of iterable

      let body = [assignValueToVariable]
               + forStatement.body.flatMap({x in process(x)})
               + [incrementIndex]

      // Reset old context
      _ = setCurrentScopeContext(oldCtx)
      return /*condStmt +*/ [assignIndexInitialValue,
        .whileStatement(BWhileStatement(
          condition: .lessThan(index, finalIndexValue),
          body: body,
          invariants: [.lessThan(.old(index), index)])
        )]

    case .emitStatement:
      // Ignore emit statements
      return []
    }
  }

  func process(_ expression: Expression, localContext: Bool = true) -> (BExpression, [BStatement]) {
    switch expression {
    case .variableDeclaration(let variableDeclaration):
      let name = translateIdentifierName(variableDeclaration.identifier.name)

      // Some variable types require shadow variables, eg dictionaries (array of keys)
      for declaration in generateVariables(variableDeclaration) {
        addCurrentFunctionVariableDeclaration(declaration)
      }
      return (.identifier(name), [])

    case .functionCall(let functionCall):
      return handleFunctionCall(functionCall,
                                structInstance: self.structInstanceVariableName == nil ? nil :
                                  .identifier(self.structInstanceVariableName!))

    case .identifier(let identifier):
      return processIdentifier(identifier, localContext: localContext)

    case .binaryExpression(let binaryExpression):
      return process(binaryExpression)

    case .bracketedExpression(let bracketedExpression):
      return process(bracketedExpression.expression)

    case .subscriptExpression(let subscriptExpression):
      let (subExpr, subStmts) = process(subscriptExpression.baseExpression, localContext: localContext)
      let (indxExpr, indexStmts) = process(subscriptExpression.indexExpression, localContext: true)
      return (.mapRead(subExpr, indxExpr), subStmts + indexStmts)

    case .literal(let token):
      return (process(token), [])

    case .inoutExpression(let inoutExpression):
      return process(inoutExpression.expression) // TODO: Consider cases where we need to do pass by reference

    case .rawAssembly:
      print("Not implemented translating raw assembly")
      fatalError()

    case .`self`:
      return (.nop, [])

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

  func process(_ binaryExpression: BinaryExpression) -> (BExpression, [BStatement]) {
    let lhs = binaryExpression.lhs
    let rhs = binaryExpression.rhs

    switch binaryExpression.opToken {
    case .dot:
      return processDotBinaryExpression(binaryExpression, [])
    case .equal:
      return handleAssignment(lhs, rhs)
    case .plusEqual:
      let (rhsExpr, rhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts) = process(lhs)
      return (lhsExpr, lhsStmts + rhsStmts + [.assignment(lhsExpr, .add(lhsExpr, rhsExpr))])
    case .minusEqual:
      let (rhsExpr, rhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts) = process(lhs)
      return (lhsExpr, lhsStmts + rhsStmts + [.assignment(lhsExpr, .subtract(lhsExpr, rhsExpr))])
    case .timesEqual:
      let (rhsExpr, rhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts) = process(lhs)
      return (lhsExpr, lhsStmts + rhsStmts + [.assignment(lhsExpr, .multiply(lhsExpr, rhsExpr))])
    case .divideEqual:
      let (rhsExpr, rhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts) = process(lhs)
      return (lhsExpr, lhsStmts + rhsStmts + [.assignment(lhsExpr, .divide(lhsExpr, rhsExpr))])

    case .plus:
      let (rhsExpr, rhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts) = process(lhs)
      return (.add(lhsExpr, rhsExpr), lhsStmts + rhsStmts)
    case .minus:
      let (rhsExpr, rhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts) = process(lhs)
      return (.subtract(lhsExpr, rhsExpr), lhsStmts + rhsStmts)
    case .times:
      let (rhsExpr, rhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts) = process(lhs)
      return (.multiply(lhsExpr, rhsExpr), lhsStmts + rhsStmts)
    case .divide:
      let (rhsExpr, rhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts) = process(lhs)
      return (.divide(lhsExpr, rhsExpr), lhsStmts + rhsStmts)

    //TODO Handle unsafe operators
    //case .overflowingPlus:
    //case .overflowingMinus:
    //case .overflowingTimes:

    //TODO: Handle power operator
    //case .power:

    // Comparisons
    case .doubleEqual:
      let (rhsExpr, rhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts) = process(lhs)
      return (.equals(lhsExpr, rhsExpr), lhsStmts + rhsStmts)
    case .notEqual:
      let (rhsExpr, rhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts) = process(lhs)
      return (.not(.equals(lhsExpr, rhsExpr)), lhsStmts + rhsStmts)
    case .openAngledBracket:
      let (rhsExpr, rhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts) = process(lhs)
      return (.lessThan(lhsExpr, rhsExpr), lhsStmts + rhsStmts)
    case .closeAngledBracket:
      let (rhsExpr, rhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts) = process(lhs)
      return (.greaterThan(lhsExpr, rhsExpr), lhsStmts + rhsStmts)
    case .lessThanOrEqual:
      let (rhsExpr, rhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts) = process(lhs)
      return (.or(.lessThan(lhsExpr, rhsExpr), .equals(lhsExpr, rhsExpr)), lhsStmts + rhsStmts)
    case .greaterThanOrEqual:
      let (rhsExpr, rhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts) = process(lhs)
      return (.not(.lessThan(lhsExpr, rhsExpr)), lhsStmts + rhsStmts)
    case .or:
      let (rhsExpr, rhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts) = process(lhs)
      return (.or(lhsExpr, rhsExpr), lhsStmts + rhsStmts)
    case .and:
      let (rhsExpr, rhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts) = process(lhs)
      return (.and(lhsExpr, rhsExpr), lhsStmts + rhsStmts)

    case .percent:
      let (rhsExpr, rhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts) = process(lhs)
      return (.modulo(lhsExpr, rhsExpr), lhsStmts + rhsStmts)

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

  private func handleAssignment(_ lhs: Expression, _ rhs: Expression) -> (BExpression, [BStatement]) {
    let (lhsExpr, lhsStmts) = process(lhs)

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

    switch rhs {
    case .arrayLiteral(let arrayLiteral):
      let literalVariableName = generateRandomIdentifier(prefix: "lit_")
      addCurrentFunctionVariableDeclaration(BVariableDeclaration(name: literalVariableName,
                                                                 rawName: literalVariableName,
                                                                 type: convertType(lhsType)))
      var assignmentStmts = [BStatement]()
      var counter = 0
      for expression in arrayLiteral.elements {
        let (bexpr, preStatements) = process(expression)
        assignmentStmts += preStatements
        assignmentStmts.append(.assignment(.mapRead(.identifier(literalVariableName), .integer(counter)), bexpr))
        counter += 1
      }
      return (lhsExpr, lhsStmts + assignmentStmts + [.assignment(lhsExpr, .identifier(literalVariableName))])

    case .dictionaryLiteral(let dictionaryLiteral):
      let literalVariableName = generateRandomIdentifier(prefix: "lit_")
      addCurrentFunctionVariableDeclaration(BVariableDeclaration(name: literalVariableName,
                                                                 rawName: literalVariableName,
                                                                 type: convertType(lhsType)))
      var assignmentStmts = [BStatement]()
      for entry in dictionaryLiteral.elements {
        let (bKeyExpr, bKeyPreStatements) = process(entry.key)
        let (bValueExpr, bValuePreStatements) = process(entry.value)
        assignmentStmts += bKeyPreStatements
        assignmentStmts += bValuePreStatements

        assignmentStmts.append(.assignment(.mapRead(.identifier(literalVariableName), bKeyExpr), bValueExpr))
      }
      return (lhsExpr, lhsStmts + assignmentStmts + [.assignment(lhsExpr, .identifier(literalVariableName))])

    default:
      break
    }

    let (rhsExpr, rhsStmts) = process(rhs)
    return (lhsExpr, lhsStmts + rhsStmts + [.assignment(lhsExpr, rhsExpr)])
  }

  private func processDotBinaryExpression(_ binaryExpression: BinaryExpression,
                                          _ seenFields: [(BExpression, [BStatement])]) -> (BExpression, [BStatement]) {

    let lhs = binaryExpression.lhs
    let rhs = binaryExpression.rhs

    switch lhs {
    case .`self`:
      // self.A, means get the A in the contract, not the local declaration
      return process(rhs, localContext: false)
    default: break
    }

    // For struct fields and methods (eg array size..)
    let currentType = getCurrentTLDName()
    guard let scopeContext = getCurrentFunction().scopeContext else {
      print("couldn't get scope context of current function - used to determine if accessing struct property")
      fatalError()
    }
    let callerProtections = getCurrentContractBehaviorDeclaration()?.callerProtections ?? []
    let typeStates = getCurrentContractBehaviorDeclaration()?.states ?? []
    let lhsType = environment.type(of: lhs,
                                   enclosingType: currentType,
                                   typeStates: typeStates,
                                   callerProtections: callerProtections,
                                   scopeContext: scopeContext)
    // Is type of lhs a struct
    switch lhsType {
    case .stdlibType(.wei):
      let holyAccesses = handleNestedStructAccess(structName: "Wei",
                                                  access: rhs)
      let (lExpr, lStmts) = process(lhs)
      let (finalExpr, holyStmts) = holyAccesses(lExpr)
      return (finalExpr, lStmts + holyStmts)

    case .userDefinedType(let structName):
      // Return function which returns BExpr to access field
      let holyAccesses = handleNestedStructAccess(structName: structName,
                                                  access: rhs)
      let (lExpr, lStmts) = process(lhs)
      let (finalExpr, holyStmts) = holyAccesses(lExpr)
      return (finalExpr, lStmts + holyStmts)
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
                  [])
        default:
          break
        }
      }
    default:
      break
    }

    print("Unknown type used with `dot` operator \(lhsType)")
    print("\(lhs)")
    print("\(rhs)")
    fatalError()
  }

  private func handleNestedStructAccess(structName: String,
                                        access: Expression) -> ((BExpression) -> (BExpression, [BStatement])) {
    switch access {
    // Final accesses of dot chain \/ \/ \/
    case .identifier(let identifier):
      let translatedIdentifier = normaliser.translateGlobalIdentifierName(identifier.name, tld: structName)
      let lhsExpr = BExpression.identifier(translatedIdentifier)
      return ({ structInstance in (.mapRead(lhsExpr, structInstance), []) })

    case .subscriptExpression(let subscriptExpression):
      guard let accessEnclosingType = access.enclosingType else {
        print("Unable to get enclosing type of struct access \(access)")
        fatalError()
      }
      let holyBase = handleNestedStructAccess(structName: accessEnclosingType,
                                              access: subscriptExpression.baseExpression)
      let (indexExpr, indexStmts) = process(subscriptExpression.indexExpression)

      return ({ structInstance in
                let (holyExpr, holyStmts) = holyBase(structInstance)
                return (.mapRead(holyExpr, indexExpr), holyStmts + indexStmts)
              })

    case .functionCall(let functionCall):
      return ({ structInstance in self.handleFunctionCall(functionCall,
                                                          structInstance: structInstance,
                                                          owningType: structName) })

    // Accessing another struct field \/ \/ \/
    case .binaryExpression(let binaryEx) where binaryEx.opToken == .dot:
      let currentType = getCurrentTLDName()
      guard let scopeContext = getCurrentFunction().scopeContext else {
        print("couldn't get scope context of current function - used to determine if accessing struct property")
        fatalError()
      }
      let callerProtections = getCurrentContractBehaviorDeclaration()?.callerProtections ?? []
      let typeStates = getCurrentContractBehaviorDeclaration()?.states ?? []
      let lhsType = environment.type(of: binaryEx.lhs,
                                     enclosingType: currentType,
                                     typeStates: typeStates,
                                     callerProtections: callerProtections,
                                     scopeContext: scopeContext)

      let accessEnclosingType: String
      switch lhsType {
      case .stdlibType(.wei):
        accessEnclosingType = "Wei"

      case .userDefinedType(let structName):
        // Return function which returns BExpr to access field
        accessEnclosingType = structName
      default:
        print("Unknown enclosing type: \(lhsType)")
        fatalError()
      }

      let holyAccess = handleNestedStructAccess(structName: accessEnclosingType,
                                                access: binaryEx.rhs)

      let holyIdentifier = handleNestedStructAccess(structName: structName,
                                                    access: binaryEx.lhs)
      return ({ structInstance in
                let (holyIdentifier, holyIdentifierStmts) = holyIdentifier(structInstance)
                let (holyExpr, holyExprStmts) = holyAccess(holyIdentifier)
                return (holyExpr, holyIdentifierStmts + holyExprStmts)
              })

    default:
      print("Not implemented nested dot access of: \(access), yet")
      fatalError()
    }
  }

  private func processIdentifier(_ identifier: Identifier, localContext: Bool = true) -> (BExpression, [BStatement]) {
      // See if identifier is a local variable
      if localContext,
         let currentFunctionName = getCurrentFunctionName(),
         getFunctionVariableDeclarations(name: currentFunctionName)
           .filter({ $0.rawName == identifier.name })
           .count > 0 ||
          getFunctionParameters(name: currentFunctionName)
           .filter({ $0.rawName == identifier.name })
           .count > 0 {

        return (.identifier(translateIdentifierName(identifier.name)), [])
      }
      let translatedIdentifier = translateGlobalIdentifierName(identifier.name)

      // Currently in a struct, referring to a 'global' variable
      if let currentStructInstanceVariable = structInstanceVariableName {
        return (.mapRead(.identifier(translatedIdentifier),
                         .identifier(currentStructInstanceVariable)), [])
      }
      return (.identifier(translatedIdentifier), [])
  }

  // Extract the size of the iterable from the shadow variables which store it
  //TODO: Combine this with process? process(iterableSize = true?) as all the translation is the same, the only difference is that the name has to resolve to size_... and the topmost base is dicarded
  private func getIterableSizeExpression(iterable: Expression) -> BExpression {
    switch iterable {
    case .identifier(let identifier):
      return BExpression.identifier(normaliser.getArraySizeVariableName(arrayName: identifier.name))
    case .arrayLiteral(let arrayLiteral):
      return .integer(arrayLiteral.elements.count)
    case .dictionaryLiteral(let dictionaryLiteral):
      return .integer(dictionaryLiteral.elements.count)
    case .bracketedExpression(let bracketedExpression):
      return getIterableSizeExpression(iterable: bracketedExpression.expression)
    case .subscriptExpression(let subscriptExpression):
      // remove top level base
      // translate the remainder, but rename the final identifier to size_...
    //case .binaryExpression(let binaryExpression): // pretty much only dot?
    default:
      print("unhandled iterable type \(iterable) to get iterable size")
      //fatalError()
    }
    return BExpression.integer(0)
  }
}
