import AST
import Source

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

      while (!(ten_LocalVariables mod 5 == 0)) {
        havoc selector;
        assume (selector > 1 && selector < 4);

        if (selector == 2) {
          call loop_LocalVariables();
        } else if (selector == 3) {
          call scoping_LocalVariables();
        }
      }

      assert (ten_LocalVariables mod 5 == 0);
      }
    */

  // Return Boogie declarations whic htest the specification
  // Also return a list of the entry points, for the symbolic executor
  func processHolisticSpecification(willSpec: Expression,
                                    contractName: String) -> ([(SourceLocation, BIRTopLevelDeclaration)], [String]) {
    let translationInformation = TranslationInformation(sourceLocation: willSpec.sourceLocation)
    let currentContract = contractName

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

    var procedureDeclarations = [(SourceLocation, BIRTopLevelDeclaration)]()
    var procedureNames = [String]()
    //Generate new procedure for each init function - check that for all initial conditions,
    // holistic spec holds
    for initProcedure in initProcedures {
      let procedureName = entryPointBase + randomString(length: 5) //unique identifier

      let havocSelector = BStatement.havoc("selector", translationInformation)
      let assumeSelector = BStatement.assume(.and(.greaterThanOrEqual(selector, .integer(BigUInt(0))),
                                                      .lessThan(selector, .integer(BigUInt(numPublicFunctions)))), translationInformation)
      let (methodSelection, variables) = generateMethodSelection(functions: publicFunctions,
                                                                 selector: selector,
                                                                 tld: currentContract,
                                                                 translationInformation: translationInformation,
                                                                 enclosingFunctionName: procedureName)
      procedureVariables = procedureVariables.union(variables)

      let whileUnsat = BStatement.whileStatement(BWhileStatement(condition: .not(bSpec),
                                                                 body: [
                                                                   havocSelector,
                                                                   assumeSelector
                                                                 ] + methodSelection,
                                                                 invariants: [],
                                                                 ti: translationInformation))
      let assertSpec = BStatement.assertStatement(BAssertStatement(expression: bSpec,
                                                                   ti: translationInformation))
      let translatedName = normaliser.getFunctionName(function: .specialDeclaration(initProcedure),
                                                      tld: currentContract)
      let callInit = BStatement.callProcedure(BCallProcedure(returnedValues: [],
                                                             procedureName: translatedName,
                                                             arguments: [],
                                                             ti: translationInformation))
      // Add procedure call to callGraph
      addProcedureCall(procedureName, translatedName)
      let procedureStmts = [callInit, whileUnsat, assertSpec]
      let specProcedure = BIRProcedureDeclaration(
        name: procedureName,
        returnType: nil,
        returnName: nil,
        parameters: [],
        preConditions: [],
        postConditions: [],
        structInvariants: [],
        contractInvariants: [],
        globalInvariants: [],
        modifies: Set(), // All variables are modified - will be determined in IR resolution phase
        statements: procedureStmts,
        variables: procedureVariables,
        ti: translationInformation,
        isHolisticProcedure: true,
        isStructInit: false,
        isContractInit: false
      )
      procedureNames.append(procedureName)
      procedureDeclarations.append((willSpec.sourceLocation, .procedureDeclaration(specProcedure)))
    }

    return (procedureDeclarations, procedureNames)
  }

  private func generateMethodSelection(functions: [FunctionDeclaration],
                                       selector: BExpression,
                                       tld: String,
                                       translationInformation: TranslationInformation,
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
        let argumentName = "arg_" + randomString(length: 10)
        variables.append(BVariableDeclaration(name: argumentName,
                                              rawName: argumentName,
                                              type: convertType(parameter.type)))
        ifStmts.append(.havoc(argumentName, translationInformation))
        arguments.append(.identifier(argumentName))
      }

      if let returnType = returnType {
        let returnVariable = "return_" + randomString(length: 10)
        variables.append(BVariableDeclaration(name: returnVariable,
                                              rawName: returnVariable,
                                              type: convertType(returnType)))

        returnedValues.append(returnVariable)
      }

      let procedureCall = BStatement.callProcedure(BCallProcedure(returnedValues: returnedValues,
                                                                  procedureName: procedureName,
                                                                  arguments: arguments,
                                                                  ti: translationInformation))
      // Add procedure call to callGraph
      addProcedureCall(enclosingFunctionName, procedureName)
      ifStmts.append(procedureCall)
      selection.append(.ifStatement(BIfStatement(condition: .equals(selector, .integer(BigUInt(counter))),
                                                 trueCase: ifStmts,
                                                 falseCase: [],
                                                 ti: translationInformation)))

      counter += 1
    }
    return (selection, variables)
  }
}
