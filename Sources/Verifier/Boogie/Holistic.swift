import AST
import Source

import BigInt

extension BoogieTranslator {
    /* Example translated holistic spec - will(ten mod 5 == 0)
      procedure Main()
        modifies ten_LocalVariables;
        modifies stateVariable_LocalVariables;
        modifies size_0_js_LocalVariables;
        modifies js_LocalVariables;
      {
      var unsat: bool;
      bound := TRANSACTION_DEPTH;

      call init_LocalVariables();
      while (!(ten_LocalVariables mod 5 == 0) && bound > 0) {
        call number, availableFunctions := CallableFunctions();
        if (number == 0) {
          break;
        }
        call SelectFunction(number, availableFunctions);
        bound := bound - 1;
      }

      assert (ten_LocalVariables mod 5 == 0);
      }
    */

  // Return Boogie declarations whic htest the specification
  // Also return a list of the entry points, for the symbolic executor
  func processHolisticSpecification(willSpec: Expression,
                                    contractName: String,
                                    structInvariants: [BIRInvariant],
                                    transactionDepth: Int) -> (SourceLocation, [BIRTopLevelDeclaration], String) {
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
    if initProcedures.count > 1 {
      print("not implemented holistic spec for multiple contract inits")
      fatalError()
    }

    // Creating main procedure to execute
    var procedureVariables = Set<BVariableDeclaration>()

    let bound = BExpression.identifier("bound")
    procedureVariables.insert(BVariableDeclaration(name: "bound",
                                                   rawName: "bound",
                                                   type: .int))
    let setBound = BStatement.assignment(bound, .integer(BigUInt(transactionDepth)), translationInformation)
    let decrementBound = BStatement.assignment(bound, .subtract(bound, .integer(1)), translationInformation)

    //Generate new procedure for each init function - check that for all initial conditions,
    // holistic spec holds
    let initProcedure = initProcedures.first!
    let procedureName = entryPointBase + randomString(length: 5) //unique identifier

    let (callableFunctionsNum, callableFunctions, callableProcedure)
      = generateCallableFunctions(functions: publicFunctions,
                                  tld: currentContract,
                                  translationInformation: translationInformation)

    procedureVariables.insert(BVariableDeclaration(name: callableFunctionsNum,
                                                   rawName: callableFunctionsNum,
                                                   type: .int))
    procedureVariables.insert(BVariableDeclaration(name: callableFunctions,
                                                   rawName: callableFunctions,
                                                   type: .map(.int, .int)))

    let getCallableFunctions = BStatement.callProcedure(BCallProcedure(returnedValues: [callableFunctionsNum, callableFunctions],
                                                                       procedureName: callableProcedure.name,
                                                                       arguments: [],
                                                                       ti: translationInformation))

    let checkNumCallableFunctions = BStatement.ifStatement(BIfStatement(condition: .equals(.identifier(callableFunctionsNum),
                                                                                           .integer(0)),
                                                                        trueCase: [.breakStatement],
                                                                        falseCase: [],
                                                                        ti: translationInformation))

    let selectFunctionProcedure = generateSelectFunction(functions: publicFunctions,
                                                         tld: currentContract,
                                                         translationInformation: translationInformation)

    let callSelectFunction = BStatement.callProcedure(BCallProcedure(returnedValues: [],
                                                                     procedureName: selectFunctionProcedure.name,
                                                                     arguments: [.identifier(callableFunctionsNum), .identifier(callableFunctions)],
                                                                     ti: translationInformation))

    let whileBody = [
      // call callable functions method
      getCallableFunctions,
      // check if 0 functions are returned
      checkNumCallableFunctions,
      // call select function method
      callSelectFunction,
      // decrement bound counter
      decrementBound
    ]

    let whileUnsat = BStatement.whileStatement(BWhileStatement(condition: .and(.greaterThan(bound, .integer(0)), .not(bSpec)),
                                                               body: whileBody,
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
    addProcedureCall(procedureName, "CallableFunctions")
    addProcedureCall(procedureName, "SelectFunction")

    let procedureStmts = [setBound, callInit, whileUnsat, assertSpec]
    let specProcedure = BIRProcedureDeclaration(
      name: procedureName,
      returnTypes: nil,
      returnNames: nil,
      parameters: [],
      preConditions: [],
      postConditions: [],
      structInvariants: structInvariants,
      contractInvariants: (tldInvariants[currentContract] ?? []),
      globalInvariants: self.globalInvariants,
      modifies: Set(), // All variables are modified - will be determined in IR resolution phase
      statements: procedureStmts,
      variables: procedureVariables,
      inline: false,
      ti: translationInformation,
      isHolisticProcedure: true,
      isStructInit: false,
      isContractInit: false
    )

    let declaredProcedures: [BIRTopLevelDeclaration] = [
      .procedureDeclaration(selectFunctionProcedure),
      .procedureDeclaration(callableProcedure),
      .procedureDeclaration(specProcedure)
    ]

    return (willSpec.sourceLocation, declaredProcedures, procedureName)
  }

  private func generateCallableFunctions(functions: [FunctionDeclaration],
                                         tld: String,
                                         translationInformation: TranslationInformation) -> (String, String, BIRProcedureDeclaration) {
    /*
        procedure CallableFunctions() returns (functions: int, callable_functions: [int]int)
        {
          var count: int;
          var tmp_callable_functions: [int]int;

          count := 0;
          // Testing if function 1's pre-conditions are currently satisfied
          if (FUNC1_PRE_CONDITIONS) {
            tmp_callable_functions[count] = FUNC1_GLOBAL_ID;
            count := count + 1;
          }
          if (FUNC2_PRE_CONDITIONS) {
            tmp_callable_functions[count] = FUNC2_GLOBAL_ID;
            count := count + 1;
          } ...

          functions := count;
          callable_functions := tmp_callable_functions;
          return;
        }
    */

    var procedureStmts = [BStatement]()
    var procedureVariables = Set<BVariableDeclaration>()

    procedureVariables.insert(BVariableDeclaration(name: "count",
                                                   rawName: "count",
                                                   type: .int))
    procedureVariables.insert(BVariableDeclaration(name: "tmp_callable_functions",
                                                   rawName: "tmp_callable_functions",
                                                   type: .map(.int, .int)))

    procedureStmts.append(.assignment(.identifier("count"), .integer(0), translationInformation))

    var count = 0
    for function in functions {
      let funcID = count
      let ifPreTrue: [BStatement] = [
        .assignment(.mapRead(.identifier("tmp_callable_functions"), .identifier("count")), .integer(BigUInt(funcID)), translationInformation),
        .assignment(.identifier("count"), .add(.identifier("count"), .integer(1)), translationInformation)
      ]

      let (testExpr, localVariables) = generateFunctionPreConditionTest(function: function, tld: tld)

      for variable in localVariables {
        procedureStmts.append(.havoc(variable.name, translationInformation))
      }

      procedureVariables = procedureVariables.union(localVariables)

      procedureStmts.append(.ifStatement(BIfStatement(condition: testExpr,
                                                      trueCase: ifPreTrue,
                                                      falseCase: [],
                                                      ti: translationInformation)))
      count += 1
    }

    procedureStmts.append(.assignment(.identifier("functions"), .identifier("count"), translationInformation))
    procedureStmts.append(.assignment(.identifier("callable_functions"), .identifier("tmp_callable_functions"), translationInformation))

    return ("functions", "callable_functions", BIRProcedureDeclaration(
      name: "CallableFunctions",
      returnTypes: [BType.int, BType.map(.int, .int)],
      returnNames: ["functions", "callable_functions"],
      parameters: [],
      preConditions: [],
      postConditions: [],
      structInvariants: [],
      contractInvariants: [],
      globalInvariants: [],
      modifies: Set(), // All variables are modified - will be determined in IR resolution phase
      statements: procedureStmts,
      variables: procedureVariables,
      inline: false,
      ti: translationInformation,
      isHolisticProcedure: true,
      isStructInit: false,
      isContractInit: false
    ))
  }

  private func generateFunctionPreConditionTest(function: FunctionDeclaration,
                                                tld: String,
                                                localVariables: [String: String]? = nil) -> (BExpression, Set<BVariableDeclaration>) {
      // Get function arguments
      // - create local versions (rename them)
      // - replace pre-condition uses of them with local versions
      // - use that to test pre-conditions on

    let procedureName = normaliser.getFunctionName(function: .functionDeclaration(function), tld: tld)
    guard let procedure = self.functionMapping[procedureName] else {
      print("couldn't find corresponding procedure for function \(procedureName), in holistic translation")
      fatalError()
    }

    let parameters = procedure.parameters.map({ ($0.name, $0.type) })
    var localVariables = localVariables ?? Dictionary(uniqueKeysWithValues: parameters.map({ ($0.0, $0.0 + randomString(length: 5)) }))
    let paramType = Dictionary(uniqueKeysWithValues: parameters.map({ (localVariables[$0.0] ?? "", $0.1) }))
    let preConditions = procedure.preConditions.map({ replaceParameterNames(preCondition: $0,
                                                                            variableReplace: localVariables) })

    // combine pre conditions
    let preConditionTest = preConditions.reduce(BExpression.boolean(true), { BExpression.and($0, $1.expression) })

    return (preConditionTest, Set(localVariables.values.map({ BVariableDeclaration(name: $0, rawName: $0, type: paramType[$0]!) })))
  }

  private func replaceParameterNames(preCondition: BPreCondition,
                                     variableReplace: [String: String]) -> BPreCondition {
    return BPreCondition(expression: replaceIdentifiers(expression: preCondition.expression,
                                                        variableReplace: variableReplace),
                         ti: preCondition.ti,
                         free: preCondition.free)
  }

  private func replaceIdentifiers(expression: BExpression,
                                  variableReplace: [String: String]) -> BExpression {
    switch expression {
    case .equivalent(let lhs, let rhs):
      return .equivalent(replaceIdentifiers(expression: lhs, variableReplace: variableReplace),
                         replaceIdentifiers(expression: rhs, variableReplace: variableReplace))
    case .implies(let lhs, let rhs):
      return .implies(replaceIdentifiers(expression: lhs, variableReplace: variableReplace),
                      replaceIdentifiers(expression: rhs, variableReplace: variableReplace))
    case .or(let lhs, let rhs):
      return .or(replaceIdentifiers(expression: lhs, variableReplace: variableReplace),
                 replaceIdentifiers(expression: rhs, variableReplace: variableReplace))
    case .and(let lhs, let rhs):
      return .and(replaceIdentifiers(expression: lhs, variableReplace: variableReplace),
                  replaceIdentifiers(expression: rhs, variableReplace: variableReplace))
    case .equals(let lhs, let rhs):
      return .equals(replaceIdentifiers(expression: lhs, variableReplace: variableReplace),
                     replaceIdentifiers(expression: rhs, variableReplace: variableReplace))
    case .lessThan(let lhs, let rhs):
      return .lessThan(replaceIdentifiers(expression: lhs, variableReplace: variableReplace),
                       replaceIdentifiers(expression: rhs, variableReplace: variableReplace))
    case .lessThanOrEqual(let lhs, let rhs):
      return .lessThanOrEqual(replaceIdentifiers(expression: lhs, variableReplace: variableReplace),
                              replaceIdentifiers(expression: rhs, variableReplace: variableReplace))
    case .greaterThan(let lhs, let rhs):
      return .greaterThan(replaceIdentifiers(expression: lhs, variableReplace: variableReplace),
                         replaceIdentifiers(expression: rhs, variableReplace: variableReplace))
    case .greaterThanOrEqual(let lhs, let rhs):
      return .greaterThanOrEqual(replaceIdentifiers(expression: lhs, variableReplace: variableReplace),
                                 replaceIdentifiers(expression: rhs, variableReplace: variableReplace))
    case .concat(let lhs, let rhs):
      return .concat(replaceIdentifiers(expression: lhs, variableReplace: variableReplace),
                     replaceIdentifiers(expression: rhs, variableReplace: variableReplace))
    case .add(let lhs, let rhs):
      return .add(replaceIdentifiers(expression: lhs, variableReplace: variableReplace),
                  replaceIdentifiers(expression: rhs, variableReplace: variableReplace))
    case .subtract(let lhs, let rhs):
      return .subtract(replaceIdentifiers(expression: lhs, variableReplace: variableReplace),
                       replaceIdentifiers(expression: rhs, variableReplace: variableReplace))
    case .multiply(let lhs, let rhs):
      return .multiply(replaceIdentifiers(expression: lhs, variableReplace: variableReplace),
                       replaceIdentifiers(expression: rhs, variableReplace: variableReplace))
    case .divide(let lhs, let rhs):
      return .divide(replaceIdentifiers(expression: lhs, variableReplace: variableReplace),
                     replaceIdentifiers(expression: rhs, variableReplace: variableReplace))
    case .modulo(let lhs, let rhs):
      return .modulo(replaceIdentifiers(expression: lhs, variableReplace: variableReplace),
                     replaceIdentifiers(expression: rhs, variableReplace: variableReplace))
    case .not(let expression):
      return .not(replaceIdentifiers(expression: expression, variableReplace: variableReplace))
    case .negate(let expression):
      return .negate(replaceIdentifiers(expression: expression, variableReplace: variableReplace))
    case .mapRead(let map, let key):
      return .mapRead(replaceIdentifiers(expression: map, variableReplace: variableReplace),
                      replaceIdentifiers(expression: key, variableReplace: variableReplace))
    case .identifier(let string): return .identifier(variableReplace[string] ?? string)
    case .old(let expression):
      return .old(replaceIdentifiers(expression: expression, variableReplace: variableReplace))
    case .quantified(let quantifier, let parameterDeclaration, let expression):
      return .quantified(quantifier, parameterDeclaration, replaceIdentifiers(expression: expression,
                                                                              variableReplace: variableReplace))
    case .functionApplication(let functionName, let arguments):
      let argumentsComponent = arguments.map({ replaceIdentifiers(expression: $0, variableReplace: variableReplace) })
      return .functionApplication(variableReplace[functionName] ?? functionName, argumentsComponent)
    case .boolean, .integer, .real, .nop: return expression
    }
  }

  private func generateSelectFunction(functions: [FunctionDeclaration],
                                      tld: String,
                                      translationInformation: TranslationInformation) -> BIRProcedureDeclaration {
    /*
    procedure SelectFunction(functions: int, callable_functions: [int]int)
      modifies ten_LocalVariables;
      modifies stateVariable_LocalVariables;
      modifies size_0_js_LocalVariables;
      modifies js_LocalVariables;
    {
      var selector_index, selected_function: int;

      // Function arguments + return values
      var arg1, arg2, ... result_value: int;

      havoc selector_index;
      // Make sure selector_index has a valid range
      assume (0 <= selector_index && selector_index < functions);
      selected_function = callable_functions[selector_index];

      if (selected_function == FUNC1_GLOBAL_ID) {
        call result_value := proc_1();
      } else if (selected_function == FUNC2_GLOBAL_ID) {
        havoc arg1, arg2 ...;
        call proc_2(arg1, arg2...);
      } ...
    }
    */

    var procedureVariables = Set<BVariableDeclaration>()

    let selector = BExpression.identifier("selector")
    procedureVariables.insert(BVariableDeclaration(name: "selector",
                                                   rawName: "selector",
                                                   type: .int))

    let numFunctions = "numFunctions_" + randomString(length: 5)
    let callableFunctions = "callableFunctions_" + randomString(length: 5)

    let havocSelector = BStatement.havoc("selector", translationInformation)
    let assumeSelector = BStatement.assume(.and(.greaterThanOrEqual(selector, .integer(BigUInt(0))),
                                                    .lessThan(selector, .identifier(numFunctions))), translationInformation)
    let selectedFunction = BExpression.identifier("selectedFunction")
    procedureVariables.insert(BVariableDeclaration(name: "selectedFunction",
                                                   rawName: "selectedFunction",
                                                   type: .int))
    let assignSelectedFunction = BStatement.assignment(selectedFunction, .mapRead(.identifier(callableFunctions), selector), translationInformation)

    var selectionStmts = [BStatement]()
    selectionStmts.append(havocSelector)
    selectionStmts.append(assumeSelector)
    selectionStmts.append(assignSelectedFunction)

    var counter = 0
    for function in functions {
      let procedureName = normaliser.getFunctionName(function: .functionDeclaration(function), tld: tld)
      guard let procedure = self.functionMapping[procedureName] else {
        print("couldn't get function mapping \(procedureName) for holistic translation")
        fatalError()
      }
      let callParamters = procedure.parameters
      let returnType = function.signature.resultType

      var ifStmts = [BStatement]()
      var returnedValues = [String]()
      var arguments = [BExpression]()

      var localVariableMapping = [String: String]()
      for parameter in callParamters {
        //declare argument variable
        //havoc argument
        let argumentName = "arg_" + randomString(length: 10)
        localVariableMapping[parameter.name] = argumentName
        procedureVariables.insert(BVariableDeclaration(name: argumentName,
                                              rawName: argumentName,
                                              type: parameter.type))
        ifStmts.append(.havoc(argumentName, translationInformation))
        arguments.append(.identifier(argumentName))
      }

      if let returnType = returnType {
        let returnVariable = "return_" + randomString(length: 10)
        procedureVariables.insert(BVariableDeclaration(name: returnVariable,
                                              rawName: returnVariable,
                                              type: convertType(returnType)))

        returnedValues.append(returnVariable)
      }

      let procedureCall = BStatement.callProcedure(BCallProcedure(returnedValues: returnedValues,
                                                                  procedureName: procedureName,
                                                                  arguments: arguments,
                                                                  ti: translationInformation))
      // Get function pre-conditions
      // TODO: Also get caller capabilities
      let (testExpr, _) = generateFunctionPreConditionTest(function: function,
                                                                        tld: tld,
                                                                        localVariables: localVariableMapping)
      ifStmts.append(.assume(testExpr, translationInformation))

      // Add procedure call to callGraph
      addProcedureCall("SelectFunction", procedureName)
      ifStmts.append(procedureCall)

      let selectedFunctionTest = BExpression.equals(selectedFunction, .integer(BigUInt(counter)))
      selectionStmts.append(.ifStatement(BIfStatement(condition: selectedFunctionTest,
                                                 trueCase: ifStmts,
                                                 falseCase: [],
                                                 ti: translationInformation)))

      counter += 1
    }

    return BIRProcedureDeclaration(
      name: "SelectFunction",
      returnTypes: nil,
      returnNames: nil,
      parameters: [BParameterDeclaration(name: numFunctions, rawName: numFunctions, type: .int), BParameterDeclaration(name: callableFunctions, rawName: callableFunctions, type: .map(.int, .int))],
      preConditions: [],
      postConditions: [],
      structInvariants: [],
      contractInvariants: [],
      globalInvariants: [],
      modifies: Set(), // All variables are modified - will be determined in IR resolution phase
      statements: selectionStmts,
      variables: procedureVariables,
      inline: true,
      ti: translationInformation,
      isHolisticProcedure: true,
      isStructInit: false,
      isContractInit: false
    )
  }
}
