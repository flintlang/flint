import AST

import BigInt

extension BoogieTranslator {
    /* Example translated holistic spec - will(ten mod 5 == 0)
      var selector: int;
      procedure Main()
        modifies ten_LocalVariables;
        modifies stateVariable_LocalVariables;
        modifies size_0_js_LocalVariables;
        modifies js_LocalVariables;
        modifies selector;
      {
      var unsat: bool;
      var arg1, a: int;

      call init_LocalVariables(); /// This does limit the response somewhat - it means we're only checking Will (A), wrt to the initial configuration. Could replace with invariant instead?

      unsat := true;

      while (unsat) {
        havoc selector;
        assume (selector > 1 && selector < 4);

        if (selector == 2) {
          call loop_LocalVariables();
        } else if (selector == 3) {
          call scoping_LocalVariables();
        }
        unsat := !(ten_LocalVariables mod 5 == 0);
      }

      assert (ten_LocalVariables mod 5 == 0);
      }
    */

  // Return Boogie declarations whic htest the specification
  // Also return a list of the entry points, for the symbolic executor
  func processHolisticSpecification(willSpec: Expression,
                                    contractDeclaration: ContractDeclaration) -> ([BIRTopLevelDeclaration], [String]) {
    let source = willSpec.sourceLocation
    let mark = registerProofObligation(source)
    let currentContract = contractDeclaration.identifier.name

    //TODO: Do analysis on willSpec, see if more than one procedure needs making or something?
    let bSpec = process(willSpec).0 // TODO: Handle +=1 in spec
    let entryPointBase = "Main_"
    let publicFunctions = self.environment.functions(in: currentContract)
                                    .map({ $0.value })
                                    .reduce([], +)
                                    .map({ $0.declaration })
                                    .filter({ $0.isPublic })
    let initProcedures = self.environment.initializers(in: currentContract).map({ $0.declaration })
    var procedureVariables = Set<BVariableDeclaration>()

    let numPublicFunctions = publicFunctions.count
    let selector = BExpression.identifier("selector")
    procedureVariables.insert(BVariableDeclaration(name: "selector",
                                                   rawName: "selector",
                                                   type: .int))
    let unsat = BExpression.identifier("unsat")
    procedureVariables.insert(BVariableDeclaration(name: "unsat",
                                                   rawName: "unsat",
                                                   type: .boolean))

    var procedureDeclarations = [BIRTopLevelDeclaration]()
    var procedureNames = [String]()
    //Generate new procedure for each init function - check that for all initial conditions,
    // holistic spec holds
    for initProcedure in initProcedures {
      let procedureName = entryPointBase + randomString(length: 5) //unique identifier

      let initalUnsatFalse = BStatement.assignment(unsat, .boolean(true), mark)
      let havocSelector = BStatement.havoc("selector", mark)
      let assumeSelector = BStatement.assume(.and(.greaterThanOrEqual(selector, .integer(BigUInt(0))),
                                                      .lessThan(selector, .integer(BigUInt(numPublicFunctions)))), mark)
      let (methodSelection, variables) = generateMethodSelection(functions: publicFunctions,
                                                                 selector: selector,
                                                                 tld: currentContract,
                                                                 mark: mark,
                                                                 enclosingFunctionName: procedureName)
      procedureVariables = procedureVariables.union(variables)

      let checkUnsat = BStatement.assignment(unsat, .not(bSpec), mark)
      let whileUnsat = BStatement.whileStatement(BWhileStatement(condition: unsat,
                                                                 body: [
                                                                   havocSelector,
                                                                   assumeSelector
                                                                 ] + methodSelection
                                                                   + [checkUnsat],
                                                                 invariants: [],
                                                                 mark: mark))
      let assertSpec = BStatement.assertStatement(BProofObligation(expression: bSpec,
                                                                   mark: mark,
                                                                   obligationType: .assertion))
      let translatedName = normaliser.getFunctionName(function: .specialDeclaration(initProcedure),
                                                      tld: currentContract)
      let callInit = BStatement.callProcedure(BCallProcedure(returnedValues: [],
                                                             procedureName: translatedName,
                                                             arguments: [],
                                                             mark: mark))
      // Add procedure call to callGraph
      addProcedureCall(procedureName, translatedName)
      let procedureStmts = [callInit, initalUnsatFalse, whileUnsat, assertSpec]
      let specProcedure = BIRProcedureDeclaration(
        name: procedureName,
        returnType: nil,
        returnName: nil,
        parameters: [],
        prePostConditions: [],
        modifies: Set(), // All variables are modified - will be determined in IR resolution phase
        statements: procedureStmts,
        variables: procedureVariables,
        mark: mark,
        isHolisticProcedure: true
      )
      procedureNames.append(procedureName)
      procedureDeclarations.append(.procedureDeclaration(specProcedure))
    }

    return (procedureDeclarations, procedureNames)
  }

  private func generateMethodSelection(functions: [FunctionDeclaration],
                                       selector: BExpression,
                                       tld: String,
                                       mark: ErrorMappingKey,
                                       enclosingFunctionName: String) -> ([BStatement], [BVariableDeclaration]) {
    /*
        if (selector == 2) {
          call loop_LocalVariables();
        } else if (selector == 3) {
          call scoping_LocalVariables();
        }
    */
    var variables = [BVariableDeclaration]()
    var selection = [BStatement]()
    var counter = 0
    for function in functions {
      let procedureName = normaliser.getFunctionName(function: .functionDeclaration(function), tld: tld)
      let callParamters = function.signature.parameters
      let returnType = function.signature.resultType

      var ifStmts = [BStatement]()
      var returnedValues = [String]()
      var arguments = [BExpression]()

      for parameter in callParamters {
        //declare argument variable
        //havoc argument
        let argumentName = randomString(length: 10)
        variables.append(BVariableDeclaration(name: argumentName,
                                              rawName: argumentName,
                                              type: convertType(parameter.type)))
        ifStmts.append(.havoc(argumentName, mark))
        arguments.append(.identifier(argumentName))
      }

      if let returnType = returnType {
        let returnVariable = randomString(length: 10)
        variables.append(BVariableDeclaration(name: returnVariable,
                                              rawName: returnVariable,
                                              type: convertType(returnType)))

        returnedValues.append(returnVariable)
      }

      let procedureCall = BStatement.callProcedure(BCallProcedure(returnedValues: returnedValues,
                                                                  procedureName: procedureName,
                                                                  arguments: arguments,
                                                                  mark: mark))
      // Add procedure call to callGraph
      addProcedureCall(enclosingFunctionName, procedureName)
      ifStmts.append(procedureCall)
      selection.append(.ifStatement(BIfStatement(condition: .equals(selector, .integer(BigUInt(counter))),
                                                 trueCase: ifStmts,
                                                 falseCase: [],
                                                 mark: mark)))

      counter += 1
    }
    return (selection, variables)
  }
}
