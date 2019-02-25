import AST

extension BoogieTranslator {
  mutating func process(_ statement: Statement) -> [BStatement] {
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

  mutating func process(_ expression: Expression) -> (BExpression, [BStatement]) {
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
      // See if identifier is a local variable
      if let currentFunctionName = getCurrentFunctionName(),
         getFunctionVariableDeclarations(name: currentFunctionName)
           .filter({ $0.rawName == identifier.name })
           .count > 0 ||
          getFunctionParameters(name: currentFunctionName)
           .filter({ $0.rawName == identifier.name })
           .count > 0 {

        return (.identifier(translateIdentifierName(identifier.name)), [])
      }

      // Currently in a struct, referring to a 'global' variable
      if let currentStructInstanceVariable = structInstanceVariableName {
        return (.mapRead(.identifier(translateGlobalIdentifierName(identifier.name)),
                         .identifier(currentStructInstanceVariable)), [])
      }
      return (.identifier(translateGlobalIdentifierName(identifier.name)), [])

    case .binaryExpression(let binaryExpression):
      return process(binaryExpression)

    case .bracketedExpression(let bracketedExpression):
      return process(bracketedExpression.expression)

    case .subscriptExpression(let subscriptExpression):
      let (subExpr, subStmts) = process(subscriptExpression.baseExpression)
      let (indxExpr, indexStmts) = process(subscriptExpression.indexExpression)
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

    case .arrayLiteral(let arrayLiteral):
      let literalVariableName = generateRandomIdentifier(prefix: "lit_")
      addCurrentFunctionVariableDeclaration(BVariableDeclaration(name: literalVariableName,
                                                                 rawName: literalVariableName,
                                                                 //TODO: Get actual type of array
                                                                 type: .map(.int, .int)))
      var assignmentStmts = [BStatement]()
      var counter = 0
      for expression in arrayLiteral.elements {
        let (bexpr, preStatements) = process(expression)
        assignmentStmts += preStatements
        assignmentStmts.append(.assignment(.mapRead(.identifier(literalVariableName), .integer(counter)), bexpr))
        counter += 1
      }
      return (.identifier(literalVariableName), assignmentStmts)

    case .dictionaryLiteral(let dictionaryLiteral):
      let literalVariableName = generateRandomIdentifier(prefix: "lit_")
      addCurrentFunctionVariableDeclaration(BVariableDeclaration(name: literalVariableName,
                                                                 rawName: literalVariableName,
                                                                 //TODO: Get actual type of array
                                                                 type: .map(.int, .int)))
      var assignmentStmts = [BStatement]()
      for entry in dictionaryLiteral.elements {
        let (bKeyExpr, bKeyPreStatements) = process(entry.key)
        let (bValueExpr, bValuePreStatements) = process(entry.value)
        assignmentStmts += bKeyPreStatements
        assignmentStmts += bValuePreStatements

        assignmentStmts.append(.assignment(.mapRead(.identifier(literalVariableName), bKeyExpr), bValueExpr))
      }
      return (.identifier(literalVariableName), assignmentStmts)

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

  mutating func process(_ binaryExpression: BinaryExpression) -> (BExpression, [BStatement]) {
    let lhs = binaryExpression.lhs
    let rhs = binaryExpression.rhs

    switch binaryExpression.opToken {
    case .dot:
      switch lhs {
      case .`self`:
        // self.A, means get the A in the contract, not the local declaration

        switch rhs {
        case .identifier(let identifier):
          return (.identifier(translateGlobalIdentifierName(identifier.name)), [])
          // TODO: Implement for arrays
        default: break
        }
        print(rhs.description)
        fatalError()
        //return (rhsExpr, rhsStmts)

      // For struct fields and methods (eg array size..)
      default:
        // Need to determine type of lhs, to work out which struct we refer to
        let currentType = getCurrentTLDName()
        if let scopeContext = getCurrentFunction().scopeContext {
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
            switch rhs {
            // TODO: Struct field
            //case .identifier(let identifier):

            // Struct method
            case .functionCall(let functionCall):
              let (lhsExpr, lhsStmts) = process(lhs)
              let (functionCallEx, functionCallStmts) = handleFunctionCall(functionCall,
                                                                           structInstance: lhsExpr,
                                                                           owningType: "Wei")
              return (functionCallEx, lhsStmts + functionCallStmts)

            default:
              break
            }

          case .userDefinedType(let structName):
            switch rhs {
            // TODO: Struct field
            //case .identifier(let identifier):

            // Struct method
            case .functionCall(let functionCall):
              let (lhsExpr, lhsStmts) = process(lhs)
              let (functionCallEx, functionCallStmts) = handleFunctionCall(functionCall,
                                                                           structInstance: lhsExpr,
                                                                           owningType: structName)
              return (functionCallEx, lhsStmts + functionCallStmts)

            default:
              break
            }
          default:
            print("lhs Type")
            print(lhsType)
            break
          }
          let (rhsExpr, rhsStmts) = process(rhs)
          return (rhsExpr, rhsStmts)
        }
        print("couldn't get scope context of current function - used to determine if accessing struct property")
        fatalError()
      }

    case .equal:
      let (rhsExpr, rhsStmts) = process(rhs)
      let (lhsExpr, lhsStmts) = process(lhs)
      return (lhsExpr, lhsStmts + rhsStmts + [.assignment(lhsExpr, rhsExpr)])
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

}
