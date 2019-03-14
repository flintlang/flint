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
      return condStmt + [
        .ifStatement(BIfStatement(condition: condExpr,
                                  trueCase: ifStatement.body.flatMap({x in process(x)}),
                                  falseCase: ifStatement.elseBody.flatMap({x in process(x)}))
        )]

    case .forStatement(let forStatement):
      let (iterableExpr, condStmt) = process(forStatement.iterable)
      //TODO: Handle iterable. Move to next item -> depends on what we are incrementing

      // if iterable is:
      //  - array
      //    - iterate through
      //  - dict
      //    - shadow keys array
      //  - range
      //    - iterate through

      addCurrentFunctionVariableDeclaration(forStatement.variable)
      return condStmt + [
        .whileStatement(BWhileStatement(
          condition: iterableExpr,
          body: forStatement.body.flatMap({x in process(x)}),
          invariants: []) // TODO: invariants
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

      // TODO: Implement expressions
    /*
    case .attemptExpression(let attemptExpression):
    case .sequence(let expressions: [Expression]):
    case .range(let rangeExpression):
      */

    default:
      print("Not implemented translating \(expression.description)")
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
          return (.identifier(translateGlobalIdentifierName(rIdentifier.name, tld: lIdentifier.name)),
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

  private  func handleNestedStructAccess(structName: String,
                                         access: Expression) -> ((BExpression) -> (BExpression, [BStatement])) {
    switch access {
    // Final accesses of dot chain \/ \/ \/
    case .identifier(let identifier):
      let translatedIdentifier = translateGlobalIdentifierName(identifier.name, tld: structName)
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
}
