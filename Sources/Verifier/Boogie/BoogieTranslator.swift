import AST
import Diagnostic
import Foundation
import Lexer
import Source

import BigInt

class BoogieTranslator {
  let topLevelModule: TopLevelModule
  let environment: Environment
  let sourceContext: SourceContext
  let normaliser: IdentifierNormaliser
  let triggers: Trigger

  // Variables declared in each function
  var functionVariableDeclarations: [String: Set<BVariableDeclaration>] = [:]
  // Procedure paramters
  var functionParameters: [String: [BParameterDeclaration]] = [:]
  // Procedure mapping
  var functionMapping: [String: BIRProcedureDeclaration] = [:]
  // Name of procedure return variable
  var functionReturnVariableName: [String: String] = [:]
  // Current function returning placeholder variable name - for use in returning statement
  var currentFunctionReturningValue: String?
  // Current function returning value, to replace placeholder with
  var currentFunctionReturningValueValue: BExpression?
  // Empty Map Properties, for each type
  var emptyMapProperties: [BType: (BFunctionDeclaration, BAxiomDeclaration, String)] = [:]
  // Map of function names to the shadow variables it modifies
  var functionModifiesShadow: [String: Set<String>] = [:]
  // Map of (trait) function names to the variables it's callee's modify
  var traitFunctionMutates: [String: [Identifier]] = [:]
  // Contract dict/array size assume statements - placed at start of each function
  var functionIterableSizeAssumptions: [BStatement] = []

  // Call Graph of Boogie procedures
  var callGraph: [String: Set<String>] = [:]

  // Current behaviour member - function / special / signature declaration ..
  var currentBehaviourMember: ContractBehaviorMember?
  // Current top level declaration - contract behaviour / trait / struct ..
  var currentTLD: TopLevelDeclaration?
  // Current Caller Identifier
  var currentCallerIdentifier: Identifier?

  // Name of state variable for each contract
  var contractStateVariable: [String: String] = [:]
  // Mapping of each state name, for each contract state variable
  var contractStateVariableStates: [String: [String: Int]] = [:]
  // Statements to be placed in the constructor of the contract
  var tldConstructorInitialisations: [String: [(String, Expression)]] = [:]

  // Name of global variables in the contract
  var contractGlobalVariables: [String: [String]] = [:]
  // Name of global variables in struct
  var structGlobalVariables: [String: [String]] = [:]

  // List of invariants for each tld
  var tldInvariants: [String: [BIRInvariant]] = [:]
  // Global invariants - must hold on all contract/struct methods
  var globalInvariants: [BIRInvariant] = []
  // List of struct invariants
  var structInvariants: [BIRInvariant] = []

  var enums: [String] = []

  // Current scope context - updated by functions, loops and if statements
  var currentScopeContext: ScopeContext?

  var inInvariant: Bool = false
  var twoStateContextInvariant: Bool = false

  // Struct function instance variable
  var structInstanceVariableName: String?

  // To track whether the current statement we're processing is in do-catch block
  var enclosingDoBody: [Statement] = []
  var enclosingCatchBody: [BStatement] = []

  public init(topLevelModule: TopLevelModule,
              environment: Environment,
              sourceContext: SourceContext,
              normaliser: IdentifierNormaliser) {
    self.topLevelModule = topLevelModule
    self.environment = environment
    self.sourceContext = sourceContext
    self.normaliser = normaliser
    self.triggers = Trigger()
  }

  public func translate(holisticTransactionDepth: Int) -> BoogieTranslationIR {
    /* for everything defined in TLM, generate Boogie representation */
    self.functionModifiesShadow = collectModifiedShadowVariables()
    resolveTraitMutations()

    // Generate AST and print
    let boogieTranslationIr = generateAST(holisticTransactionDepth: holisticTransactionDepth)
    return boogieTranslationIr
  }

  func collectModifiedShadowVariables() -> [String: Set<String>] {
    let shadowVariablePass = ShadowVariablePass(normaliser: self.normaliser, triggers: self.triggers)
    _ = ASTPassRunner(ast: self.topLevelModule) .run(passes: [shadowVariablePass],
                                                     in: self.environment,
                                                     sourceContext: self.sourceContext)
    return shadowVariablePass.modifies
  }

  // If trait calls function which is implemented elsewhere, and that function mutates a value,
  // then the trait method mutates that value
  func resolveTraitMutations() {
    var functionsToFlow: [String] = []
    // Get functions in struct, which were defined in trait, for those functions,
    // add the mutated variables to their function declarations
    for case .structDeclaration(let structDeclaration) in self.topLevelModule.declarations {
      for functionInfo in self.environment.conformingFunctions(in: structDeclaration.identifier.name) {
        let name = functionInfo.declaration.name
        let parameterTypes = functionInfo.parameterTypes.compactMap({ (type) -> RawType in
          if type.isSelfType {
            let structType: RawType = .userDefinedType(structDeclaration.identifier.name)
            if type.isInout {
              return .inoutType(structType)
            }
            return structType
          }
          return type
        })
        let resultType = functionInfo.resultType

        // Use name + parameter + return type to locate corresponding function in ast
        guard let function = structDeclaration.functionDeclarations.first(where: {
                                                                            $0.name == name &&
                                                                            $0.signature.parameters.rawTypes == parameterTypes &&
                                                                            $0.signature.rawType == resultType
                                                                          }) else {
          print("Could not locate function declared in trait")
          fatalError()
        }

        let normName = normaliser.translateGlobalIdentifierName(function.name + normaliser.flattenTypes(types: parameterTypes),
                                                                tld: structDeclaration.identifier.name)
        functionsToFlow.append(normName)
      }
    }

    // This resolves user specified mutates clauses - for functions implemented in traits.
    let cfg = self.environment.callGraph
    for _ in 0...functionsToFlow.count {
      for traitFunction in functionsToFlow {
        var mutates = self.traitFunctionMutates[traitFunction] ?? [Identifier]()
        for (normalisedName, functionDeclaration)  in cfg[traitFunction] ?? [] {
          // for all traitFunction's calls, add all considering's mutates clauses to traitFunction
          // Could also call another trait method
          mutates = functionDeclaration.mutates + (self.traitFunctionMutates[normalisedName] ?? [])
        }
        self.traitFunctionMutates[traitFunction] = mutates
      }
    }
  }

  func generateAST(holisticTransactionDepth: Int) -> BoogieTranslationIR {
    var declarations: [BIRTopLevelDeclaration] = []

    // Triggers
    //TODO: Actually parse? expression rules in some format, and use that to register sourceLocations
    declarations += triggers.globalMetaVariableDeclaration.map({ .variableDeclaration($0) })
    globalInvariants += triggers.invariants

    // Add type def for Address
    declarations.append(.typeDeclaration(BTypeDeclaration(name: "Address", alias: .int)))

    // Add global send function
    // eg. send(address, wei)
    declarations.append(.procedureDeclaration(
      BIRProcedureDeclaration(
        name: "send",
        returnTypes: nil,
        returnNames: nil,
        parameters: [
          BParameterDeclaration(name: "address", rawName: "address", type: .userDefined("Address")),
          BParameterDeclaration(name: "wei", rawName: "wei", type: .int)
        ],
        preConditions: [],
        postConditions: [BPostCondition(expression:
          .equals(.mapRead(.identifier("rawValue_Wei"), .identifier("wei")), .integer(BigUInt(0))),
         ti: TranslationInformation(sourceLocation: SourceLocation.DUMMY))],
        structInvariants: [],
        contractInvariants: [],
        globalInvariants: self.globalInvariants,
        modifies: [BIRModifiesDeclaration(variable: "rawValue_Wei", userDefined: true)],
        // Drain all wei from struct
        statements: [.assignment(.mapRead(.identifier("rawValue_Wei"), .identifier("wei")),
                                 .integer(BigUInt(0)),
                                 TranslationInformation(sourceLocation: SourceLocation.DUMMY))],

        variables: [], // TODO: variables
        inline: true,
        ti: TranslationInformation(sourceLocation: SourceLocation.DUMMY),
        isHolisticProcedure: false,
        isStructInit: false,
        isContractInit: false
        )
      )
    )

    // Add global power function
    // eg. power(n, e)
    //function power(n: int, e: int) returns (i: int);
    //axiom (forall n: int :: power(n, 0) == 1);
    //axiom (forall n, e: int :: (e mod 2 == 0 && e > 0) ==> (power(n, e) == power(n, e div 2)*power(n, e div 2)));
    //axiom (forall n, e: int :: (e mod 2 == 1 && e > 0) ==> (power(n, e) == power(n, (e-1) div 2) * power(n, (e-1) div 2)*n));


    declarations.append(.functionDeclaration(BFunctionDeclaration(
      name: "power",
      returnType: .int,
      returnName: "result",
      parameters: [BParameterDeclaration(name: "n", rawName: "n", type: .int),
                   BParameterDeclaration(name: "e", rawName: "e", type: .int)]
    )))

    let powerBaseCase: BExpression = .quantified(.forall,
                                                 [BParameterDeclaration(name: "n", rawName: "n", type: .int)],
                                                 .equals(.functionApplication("power", [
                                                                                .identifier("n"),
                                                                                .integer(0)
                                                                              ]),
                                                         .integer(1)))
    let powerRecursiveCaseEven: BExpression =
    .quantified(.forall, [BParameterDeclaration(name: "n", rawName: "n", type: .int),
                          BParameterDeclaration(name: "e", rawName: "e", type: .int) ],
                .implies(
                  .and(.greaterThan(.identifier("e"), .integer(0)),
                       .equals(.modulo(.identifier("e"), .integer(2)), .integer(0))),
                  .equals(.functionApplication("power", [
                                                 .identifier("n"),
                                                 .identifier("e")
                                               ]),
                          .multiply(.functionApplication("power", [
                                                         .identifier("n"),
                                                         .divide(.identifier("e"), .integer(2))]),
                                    .functionApplication("power", [
                                                         .identifier("n"),
                                                         .divide(.identifier("e"), .integer(2))])))))
    let powerRecursiveCaseOdd: BExpression =
    .quantified(.forall, [BParameterDeclaration(name: "n", rawName: "n", type: .int),
                          BParameterDeclaration(name: "e", rawName: "e", type: .int) ],
                .implies(
                  .and(.greaterThan(.identifier("e"), .integer(0)),
                       .equals(.modulo(.identifier("e"), .integer(2)), .integer(1))),
                  .equals(.functionApplication("power", [
                                                 .identifier("n"),
                                                 .identifier("e")
                                               ]),
                          .multiply(.multiply(.functionApplication("power", [
                                                         .identifier("n"),
                                                         .divide(.subtract(.identifier("e"), .integer(1)), .integer(2))]),
                                              .functionApplication("power", [
                                                                   .identifier("n"),
                                                                   .divide(.subtract(.identifier("e"), .integer(1)), .integer(2))])),
                                    .identifier("n")))))

    declarations.append(.axiomDeclaration(BAxiomDeclaration(proposition: powerBaseCase)))
    declarations.append(.axiomDeclaration(BAxiomDeclaration(proposition: powerRecursiveCaseEven)))
    declarations.append(.axiomDeclaration(BAxiomDeclaration(proposition: powerRecursiveCaseOdd)))

    for case .structDeclaration(let structDeclaration) in topLevelModule.declarations where structDeclaration.identifier.name != "Flint$Global"{
      self.currentTLD = .structDeclaration(structDeclaration)
      let enclosingStruct = structDeclaration.identifier.name

      for declaration in structDeclaration.invariantDeclarations {
        //Invariants are turned into both pre and post conditions
        self.structInstanceVariableName = "i" // TODO: Check that i is unique

        self.inInvariant = true
        let expr = process(declaration).0 // TODO: Handle usage of += 1 and preStmts
        self.inInvariant = false

        // All allocated structs, i < nextInstance => invariantExpr
        let inv = BExpression.quantified(.forall, [BParameterDeclaration(name: structInstanceVariableName!,
                                                             rawName: structInstanceVariableName!,
                                                             type: .int)],
                                         .implies(.and(.lessThan(.identifier(self.structInstanceVariableName!),
                                                                 .identifier(normaliser.generateStructInstanceVariable(structName: enclosingStruct))),
                                                       .greaterThanOrEqual(.identifier(self.structInstanceVariableName!), .integer(0))),
                                                   expr))

        self.structInstanceVariableName = nil

        structInvariants.append(BIRInvariant(expression: inv,
                                             twoStateContext: self.twoStateContextInvariant,
                                             ti: TranslationInformation(sourceLocation: declaration.sourceLocation)))
        self.twoStateContextInvariant = false

      }

      // Generate invariant; 0 < nextInstance_tld
      structInvariants.append(BIRInvariant(expression: .greaterThanOrEqual(.identifier(normaliser.generateStructInstanceVariable(structName: getCurrentTLDName())),
                                                                                .integer(0)),
                                                ti: TranslationInformation(sourceLocation: structDeclaration.sourceLocation)))

      for variableDeclaration in structDeclaration.variableDeclarations {
        let (_, invariants) = generateVariables(variableDeclaration, tldIsStruct: true)
        structInvariants += invariants.map({ BIRInvariant(expression: $0, ti: TranslationInformation(sourceLocation: variableDeclaration.sourceLocation)) })
      }
      self.currentTLD = nil
    }

    for case .structDeclaration(let structDeclaration) in topLevelModule.declarations {
      self.currentTLD = .structDeclaration(structDeclaration)
      declarations += process(structDeclaration, structInvariants)
      self.currentTLD = nil
    }

    for case .contractDeclaration(let contractDeclaration) in topLevelModule.declarations {
      self.currentTLD = .contractDeclaration(contractDeclaration)
      // Add caller global variable, for the contract
      declarations.append(.variableDeclaration(
        BVariableDeclaration(name: translateGlobalIdentifierName("caller"),
                             rawName: translateGlobalIdentifierName("caller"),
                             type: .userDefined("Address")))
      )

      declarations += process(contractDeclaration)
      self.currentTLD = nil
    }

    for case .enumDeclaration(let enumDeclaration) in topLevelModule.declarations {
      self.currentTLD = .enumDeclaration(enumDeclaration)
      declarations += process(enumDeclaration)
      self.currentTLD = nil
    }

    for case .contractBehaviorDeclaration(let contractBehaviorDeclaration) in topLevelModule.declarations {
      self.currentTLD = .contractBehaviorDeclaration(contractBehaviorDeclaration)
      declarations += process(contractBehaviorDeclaration, structInvariants: structInvariants)
      self.currentTLD = nil
    }

    let propertyDeclarations: [BIRTopLevelDeclaration]
      = emptyMapProperties.map({ arg in
                                     let (_, v) = arg
                                     let funcDec: BFunctionDeclaration = v.0
                                     let axDec: BAxiomDeclaration = v.1
                                     return [BIRTopLevelDeclaration.functionDeclaration(funcDec),
                                             BIRTopLevelDeclaration.axiomDeclaration(axDec)]
                                   }).reduce([], +)

    var holisticTests = [(SourceLocation, [BIRTopLevelDeclaration])]()
    var holisticEntryPoints = [String]()

    for case .contractDeclaration(let contractDeclaration) in topLevelModule.declarations {
      self.currentTLD = .contractDeclaration(contractDeclaration)
      // Handle holistic specification on contract
      let contractName = contractDeclaration.identifier.name
      let holisticTranslationInformation = contractDeclaration.holisticDeclarations.map({
                                              processHolisticSpecification(willSpec: $0,
                                                                           contractName: contractName,
                                                                           structInvariants: structInvariants,
                                                                           transactionDepth: holisticTransactionDepth)
                                            })
      let (holisticDecls, entryPoints)
        = holisticTranslationInformation.reduce(([], []), { x, y in (x.0 + [(y.0, y.1)], x.1 + [y.2]) })

      holisticTests += holisticDecls
      holisticEntryPoints += entryPoints
    }
    self.currentTLD = nil

    return BoogieTranslationIR(tlds: propertyDeclarations + declarations,
                               holisticTestProcedures: holisticTests,
                               holisticTestEntryPoints: holisticEntryPoints,
                               callGraph: self.callGraph
    )
  }

   func process(_ contractDeclaration: ContractDeclaration) -> [BIRTopLevelDeclaration] {
    var declarations = [BIRTopLevelDeclaration]()
    var contractGlobalVariables = [String]()
    var invariantDeclarations = [BIRInvariant]()

    for variableDeclaration in contractDeclaration.variableDeclarations {
      let name = translateGlobalIdentifierName(variableDeclaration.identifier.name)

      //TODO: Handle dict/arrays -> generate assumes
      // Some variables require shadow variables, eg dictionaries need an array of keys
      let (variableDeclarations, invariants) = generateVariables(variableDeclaration)
      for bvariableDeclaration in variableDeclarations {
        declarations.append(.variableDeclaration(bvariableDeclaration))
        contractGlobalVariables.append(bvariableDeclaration.name)

      }

      // If variable is of type array/dict, it's need to add assume stmt about it's size to
      // functionIterableSizeAssumptions list
      functionIterableSizeAssumptions += generateIterableSizeAssumptions(name: name,
                                                                         type: variableDeclaration.type.rawType,
                                                                         source: variableDeclaration.sourceLocation,
                                                                         isInStruct: false)

      invariantDeclarations += invariants.map({ BIRInvariant(expression: $0, ti: TranslationInformation(sourceLocation: variableDeclaration.sourceLocation)) })

      // Record assignment to put in constructor procedure
      if tldConstructorInitialisations[contractDeclaration.identifier.name] == nil {
        tldConstructorInitialisations[contractDeclaration.identifier.name] = []
      }
      if let assignedExpression = variableDeclaration.assignedExpression {
        tldConstructorInitialisations[contractDeclaration.identifier.name]!.append((name, assignedExpression))
      }
    }

    let stateVariableName = normaliser.generateStateVariable(contractDeclaration.identifier.name)
    contractStateVariable[contractDeclaration.identifier.name] = stateVariableName
    // Declare contract state variable
    declarations.append(.variableDeclaration(BVariableDeclaration(name: stateVariableName,
                                                                  rawName: stateVariableName,
                                                                  type: .int)))
    contractGlobalVariables.append(stateVariableName)

    contractStateVariableStates[contractDeclaration.identifier.name] = [String: Int]()
    for typeState in contractDeclaration.states {
      contractStateVariableStates[contractDeclaration.identifier.name]![typeState.name]
        = contractStateVariableStates[contractDeclaration.identifier.name]!.count
    }


    // TODO: Handle usage of += 1 and preStmts
    for declaration in contractDeclaration.invariantDeclarations {
      //Invariants are turned into both pre and post conditions
      self.inInvariant = true
      invariantDeclarations.append(BIRInvariant(expression: process(declaration).0,
                                                twoStateContext: self.twoStateContextInvariant,
                                                ti: TranslationInformation(sourceLocation: declaration.sourceLocation)))
      self.twoStateContextInvariant = false
      self.inInvariant = false
    }
    tldInvariants[contractDeclaration.identifier.name] = invariantDeclarations

    self.contractGlobalVariables[getCurrentTLDName()] = contractGlobalVariables

    return declarations
  }

  func process(_ enumDeclaration: EnumDeclaration) -> [BIRTopLevelDeclaration] {
    //var enumType = enumDeclaration.type
    let enumName = enumDeclaration.identifier.name

    enums.append(enumName)

    // Declare type EnumName: int;
    // const var enumCase: EnumName;
    var axioms = [BIRTopLevelDeclaration]()
    axioms.append(.typeDeclaration(BTypeDeclaration(name: enumName, alias: .int)))

    //TODO: Implement for other enum types
    var counter: Int = 0

    for `case` in enumDeclaration.cases {
      let caseIdent = `case`.identifier.name
      //TODO: Do something with caseValue
      //var caseValue: BExpression
      if let value = `case`.hiddenValue {
        switch value {
        case .literal:
          // TODO: Assign the actual value of the enum
          //caseValue = process(token)
          break
        default:
          fatalError("Can't translate enum value with raw expressions")
        }
      } else {
        //caseValue = counter
        counter += 1
      }

      axioms.append(.constDeclaration(BConstDeclaration(name: normaliser.translateGlobalIdentifierName(caseIdent, tld: enumName),
                                                        rawName: enumName,
                                                        type: .userDefined(enumName),
                                                        unique: true)))
    }
    return axioms
  }

  func process(_ traitDeclaration: TraitDeclaration) -> [BIRTopLevelDeclaration] {
    // TODO:
    return []
  }

   func process(_ structDeclaration: StructDeclaration, _ structInvariantDeclarations: [BIRInvariant]) -> [BIRTopLevelDeclaration] {
    // Skip special global struct - too solidity low level - TODO: Is this necessary?
    if structDeclaration.identifier.name == "Flint$Global" { return [] }

    var structGlobalVariables = [String]()
    var declarations = [BIRTopLevelDeclaration]()

    // Add nextInstance variable
    declarations.append(.variableDeclaration(BVariableDeclaration(name: normaliser.generateStructInstanceVariable(structName: getCurrentTLDName()),
                                                                  rawName: normaliser.generateStructInstanceVariable(structName: getCurrentTLDName()),
                                                                  type: .int)))

    for variableDeclaration in structDeclaration.variableDeclarations {
      let name = translateGlobalIdentifierName(variableDeclaration.identifier.name)
      // Some variables require shadow variables, eg dictionaries need an array of keys
      let (variableDeclarations, _/*invariants are added above*/) = generateVariables(variableDeclaration, tldIsStruct: true)
      for bvariableDeclaration in variableDeclarations {
        declarations.append(.variableDeclaration(bvariableDeclaration))
        structGlobalVariables.append(bvariableDeclaration.name)
      }

      // Record assignment to put in constructor procedure
      if tldConstructorInitialisations[structDeclaration.identifier.name] == nil {
        tldConstructorInitialisations[structDeclaration.identifier.name] = []
      }
      if let assignedExpression = variableDeclaration.assignedExpression {
        tldConstructorInitialisations[structDeclaration.identifier.name]!.append((name, assignedExpression))
      }

      // If variable is of type array/dict, it's need to add assume stmt about it's size to
      // functionIterableSizeAssumptions list
      functionIterableSizeAssumptions += generateIterableSizeAssumptions(name: name,
                                                                         type: variableDeclaration.type.rawType,
                                                                         source: variableDeclaration.sourceLocation,
                                                                         isInStruct: true)
    }

    self.structGlobalVariables[getCurrentTLDName()] = structGlobalVariables

    for functionDeclaration in structDeclaration.functionDeclarations {
      self.currentBehaviourMember = .functionDeclaration(functionDeclaration)
      declarations.append(process(functionDeclaration, structInvariants: structInvariantDeclarations))
      self.currentBehaviourMember = nil
    }

    for specialDeclaration in structDeclaration.specialDeclarations {
      let initFunction = specialDeclaration.asFunctionDeclaration
      self.currentBehaviourMember = .functionDeclaration(initFunction)
      declarations.append(process(initFunction, isStructInit: true, structInvariants: structInvariantDeclarations))
      self.currentBehaviourMember = nil
    }

    return declarations
  }

  func process(_ contractBehaviorDeclaration: ContractBehaviorDeclaration,
               structInvariants: [BIRInvariant]) -> [BIRTopLevelDeclaration] {

    var declarations = [BIRTopLevelDeclaration]()

    let callerBinding = contractBehaviorDeclaration.callerBinding
    self.currentCallerIdentifier = callerBinding
    let callerProtections = contractBehaviorDeclaration.callerProtections
    let typeStates = contractBehaviorDeclaration.states

    for member in contractBehaviorDeclaration.members {
      self.currentBehaviourMember = member

      switch member {
      case .specialDeclaration(let specialDeclaration):
        declarations.append(process(specialDeclaration.asFunctionDeclaration,
                                    isContractInit: true,
                                    callerProtections: callerProtections,
                                    callerBinding: callerBinding,
                                    structInvariants: structInvariants,
                                    typeStates: typeStates))

      case .functionDeclaration(let functionDeclaration):
        declarations.append(process(functionDeclaration,
                                    callerProtections: callerProtections,
                                    callerBinding: callerBinding,
                                    structInvariants: structInvariants,
                                    typeStates: typeStates))

      default:
        // TODO: Handle functionSignatureDeclaration case
        // TODO: Handle specialFunctionSignatureDeclaration case
        print("found declaration: \(member)")
      }
      self.currentBehaviourMember = nil
    }

    return declarations
  }

  func processParameter(_ parameter: Parameter) -> ([BParameterDeclaration], [BPreCondition], [BStatement], [String]) {
    let translatedName = translateIdentifierName(parameter.identifier.name)
    var declarations = [BParameterDeclaration]()
    let translationInformation = TranslationInformation(sourceLocation: parameter.sourceLocation, isInvariant: false)

    var modifies = [String]()
    var functionPreAmble = [BStatement]()
    var functionPreCondition = [BPreCondition]()
    if parameter.isImplicit {
      // Can't call payable functions - internally
      switch parameter.type.rawType {
      case .inoutType(.userDefinedType("Wei")), .userDefinedType("Wei"):
        // value of rawValue_Wei[name] >= 0

        functionPreCondition.append(BPreCondition(expression: .greaterThanOrEqual(.mapRead(.identifier("rawValue_Wei"), .identifier(translatedName)),
                                                                                  .integer(BigUInt(0))),
                                                  ti: translationInformation))

        /// instance == nextInstance
        // increment nextInstace
        functionPreCondition.append(BPreCondition(expression: .equals(.identifier(translatedName),
                                                                      .identifier(normaliser.generateStructInstanceVariable(structName: "Wei"))),
                                                  ti: translationInformation))

        functionPreAmble.append(.assignment(.identifier(normaliser.generateStructInstanceVariable(structName: "Wei")),
                                            .add(.identifier(normaliser.generateStructInstanceVariable(structName: "Wei")), .integer(1)),
                                            translationInformation))
        modifies.append(normaliser.generateStructInstanceVariable(structName: "Wei"))
      default: break
      }
    } else {
      switch parameter.type.rawType {
      case .inoutType(.userDefinedType(let udt)):
        // instance of Wei struct, where name < nextStruct

        functionPreCondition.append(BPreCondition(expression: .lessThan(.identifier(translatedName),
                                                                   .identifier(normaliser.generateStructInstanceVariable(structName: udt))),
                                              ti: translationInformation))
      default: break
      }
    }

    let (variableDeclarations, invariants) = generateVariables(parameter.asVariableDeclaration)
    if !parameter.isImplicit {
      functionPreCondition += invariants.map({ BPreCondition(expression: $0, ti: translationInformation) })
    }

    for bvariableDeclaration in variableDeclarations {
      declarations.append(BParameterDeclaration(name: bvariableDeclaration.name,
                                                rawName: bvariableDeclaration.rawName,
                                                type: bvariableDeclaration.type))
    }

    let context = Context(environment: environment,
                          enclosingType: getCurrentTLDName(),
                          scopeContext: getCurrentScopeContext() ?? ScopeContext())
    let (triggerPreStmts, triggerPostStmts) = triggers.lookup(parameter, context, extra: ["normalised_parameter_name": translatedName])
    return (declarations, functionPreCondition, functionPreAmble + triggerPreStmts + triggerPostStmts, modifies)
  }

  func process(_ token: Token) -> BExpression {
    switch token.kind {
    case .literal(let literal):
      return process(literal)
    default:
      print("Not implemented handling other literals")
      fatalError()
    }
  }

  func process(_ literal: Token.Kind.Literal) -> BExpression {
    switch literal {
    case .boolean(let booleanLiteral):
      return .boolean(booleanLiteral == Token.Kind.BooleanLiteral.`true`)

    case .decimal(let decimalLiteral):
      switch decimalLiteral {
      case .integer(let i):
        return .integer(BigUInt(i))
      case .real(let b, let f):
        return .real(b, f)
      }

    case .string:
      // TODO: Implement strings
      // Create const string for this literal -> const normalisedString: String;
      print("Not implemented translating strings")
      fatalError()
    case .address(let hex):
      let hexValue = hex[hex.index(hex.startIndex, offsetBy: 2)...] // Hex literals are prefixed with 0x
      guard let dec = BigUInt(hexValue, radix: 16) else {
        print("Couldn't convert hex address value \(hexValue)")
        fatalError()
      }
      return .integer(dec)
    }
  }

  func processCallerCapabilities(_ callerIdentifiers: [Identifier],
                                 _ binding: Identifier?
                                 ) -> ([BPreCondition], [BStatement]) {
    var preStatements = [BStatement]()
    //if let binding = binding {
    //  let bindingName = binding.name
    //  let translatedName = translateIdentifierName(bindingName)
    //   Don't need to do this, just directly reference "caller" variable, when bindinName used - processIdentifier
    //   Create local variable (rawName = bindingName) which equals caller
    //  addCurrentFunctionVariableDeclaration(BVariableDeclaration(name: translatedName,
    //                                                             rawName: bindingName,
    //                                                             type: .userDefined("Address")))
    //  preStatements.append(.assignment(.identifier(translatedName),
    //                                   .identifier(translateGlobalIdentifierName("caller")),
    //                                   TranslationInformation(sourceLocation: binding.sourceLocation)))
    //}

    var callerPreConditions = [BPreCondition]()
    for identifier in callerIdentifiers {
      let identifierType = environment.type(of: identifier.name, enclosingType: getCurrentTLDName())

      // If identifier is a function : -> call and false = assumer false;
      // if caller is global variable -> type -> map, caller is within it else caller is it.
      switch identifierType {
      case .basicType(.address):
        callerPreConditions.append(
          BPreCondition(expression: .equals(.identifier(translateGlobalIdentifierName("caller")),
                                               .identifier(translateGlobalIdentifierName(identifier.name))),
                           ti: TranslationInformation(sourceLocation: identifier.sourceLocation))
          )
      case.arrayType(.basicType(.address)):
        // eg (exists i: int :: caller == accounts_Bank[i]);
        let existsExpr: BExpression =
          .quantified(.exists,
                      [BParameterDeclaration(name: "i", rawName: "i", type: .int)],
                      .equals(.identifier(translateGlobalIdentifierName("caller")),
                              .mapRead(.identifier(translateGlobalIdentifierName(identifier.name)),
                                       .identifier("i")
                                      )
                              )
                      )

        callerPreConditions.append(
          BPreCondition(expression: existsExpr,
                           ti: TranslationInformation(sourceLocation: identifier.sourceLocation))
          )
      case .functionType([.basicType(.address)], .basicType(.bool)):
        //insert check at start of the function -> if call returns false -> assume false
        // if call returns false, the contract would have aborted and reverted any changes
        //  -> placing it back in a valid state so np's

        // generate rand tmp variable to hold result of call
        let tmpIdentifier = generateRandomIdentifier(prefix: "cc_")
        addCurrentFunctionVariableDeclaration(BVariableDeclaration(name: tmpIdentifier,
                                                                   rawName: tmpIdentifier,
                                                                   type: .boolean))
        let functionName = normaliser.translateGlobalIdentifierName(identifier.name + normaliser.flattenTypes(types: [.basicType(.address)]),
                                                                    tld: getCurrentTLDName())

        preStatements += [
            // do call
            .callProcedure(BCallProcedure(returnedValues: [tmpIdentifier],
                                          procedureName: functionName,
                                          arguments: [.identifier(translateGlobalIdentifierName("caller"))],
                                          ti: TranslationInformation(sourceLocation: identifier.sourceLocation))),

            // check result -> if call returns false, assume false
            .ifStatement(BIfStatement(condition: .not(.identifier(tmpIdentifier)),
                                      trueCase: [BStatement.assume(.boolean(false),
                                        TranslationInformation(sourceLocation: identifier.sourceLocation))],
                                      falseCase: [],
                                      ti: TranslationInformation(sourceLocation: identifier.sourceLocation)))
        ]
        guard let currentFunctionName = getCurrentFunctionName() else {
          print("unable to get current function name - while processing caller capabilities")
          fatalError()
        }
        // Add procedure call to callGraph
        addProcedureCall(currentFunctionName, functionName)
      default:
        print("Not implemented verification of \(identifierType) caller capabilities yet")
        fatalError()
      }
    }
    return (callerPreConditions, preStatements)
  }

  func processTypeStates(_ typeStates: [TypeState]) -> [BPreCondition] {
    var conditions = [BExpression]()
    let typeStates = typeStates.filter({ !$0.isAny })
    for typeState in typeStates {
      conditions.append(.equals(.identifier(getStateVariable()),
                                // Convert typestate name to numerical representation
                                .integer(BigUInt(getStateVariableValue(typeState.name)))))
    }

    if conditions.count > 0 {
      // Only return precondition, if we have something to form a pre-condition with
      let condition = conditions.reduce(.boolean(false), { BExpression.or($0, $1) })

      let sourceLocation = SourceLocation.spanning(typeStates.first!.identifier, to: typeStates.last!.identifier)

      return [BPreCondition(expression: condition,
                               ti: TranslationInformation(sourceLocation: sourceLocation))]
    }
    return []
  }

  func generateVariables(_ variableDeclaration: VariableDeclaration,
                         tldIsStruct: Bool = false) -> ([BVariableDeclaration], [BExpression]) {
    // If currently in a function, then generate name with function in it
    // If in (contract/struct)Declaration, then generate name with only contract in it
    let name = getCurrentFunctionName() == nil ?
      translateGlobalIdentifierName(variableDeclaration.identifier.name)
      : translateIdentifierName(variableDeclaration.identifier.name)

    var declarations = [BVariableDeclaration]()
    var properties = [BExpression]()

    switch variableDeclaration.type.rawType {
    case .dictionaryType, .arrayType, .fixedSizeArrayType:
      var hole: (BType) -> BType
      if tldIsStruct {
        // Structs are a mapping from struct instance to field
        hole = { x in return .map(.int, x) }
      } else {
        hole = { $0 }
      }

      declarations += generateIterableShadowVariables(name: name,
                                                      type: variableDeclaration.type.rawType,
                                                      hole: hole)

    default:
      break
    }

    // instance < nextInstance - could be super nested in array/dict
    properties += generateUDTProperties(name: name, type: variableDeclaration.type.rawType, isStructTLD: tldIsStruct)

    let convertedType = convertType(variableDeclaration.type)
    declarations.append(BVariableDeclaration(name: name,
                                             rawName: variableDeclaration.identifier.name,
                                             type: tldIsStruct ? .map(.int, convertedType) : convertedType))
    return (declarations, properties)
  }

  private func generateUDTProperties(name: String, type: RawType, isStructTLD: Bool = false) -> [BExpression] {
    var properties = [BExpression]()
    switch type {
    case .dictionaryType, .arrayType, .fixedSizeArrayType:
      let (udt, isDict) = getDeepDictTypesTilUDT(type: type)
      if udt == "" {
        // No nested udt
        return []
      }
      let namedParams = isDict.enumerated().map({ ("i\($0.0)", $0.1) })
      let params = namedParams.map({ BParameterDeclaration(name: $0.0, rawName: $0.0, type: .int) })
      let nestedReadsExpr = nestedReads(base: (isStructTLD ? { .mapRead(.identifier($0), .identifier("i")) } : { .identifier($0) }), params: namedParams, name: name)
      let inSizeRange = sizeConstraints(base: { (isStructTLD ? .mapRead(.identifier(normaliser.getShadowArraySizePrefix(depth: $0) + name), .identifier("i")) : .identifier(normaliser.getShadowArraySizePrefix(depth: $0) + name))}, paramNames: namedParams.map({ $0.0 }))
      properties.append(.quantified(.forall,
                                    (isStructTLD ? [BParameterDeclaration(name: "i", rawName: "i", type: .int)] : []) + params,
                                    .implies(inSizeRange,
                                             .and(.lessThan(nestedReadsExpr,
                                                            .identifier(normaliser.generateStructInstanceVariable(structName: udt))),
                                                  .greaterThanOrEqual(nestedReadsExpr, .integer(0))))))

    // If type is struct then invariant that value < nextInstance
    case .inoutType(.userDefinedType(let udt)), .userDefinedType(let udt):
      if isStructTLD {
        properties.append(.quantified(.forall,
                                      [BParameterDeclaration(name: "i", rawName: "i", type: .int)],
                                      .and(.lessThan(.mapRead(.identifier(name), .identifier("i")),
                                                     .identifier(normaliser.generateStructInstanceVariable(structName: udt))),
                                           .greaterThanOrEqual(.mapRead(.identifier(name), .identifier("i")), .integer(0)))))
      } else {
        properties.append(.and(.lessThan(.identifier(name),
                                         .identifier(normaliser.generateStructInstanceVariable(structName: udt))),
                               .greaterThanOrEqual(.identifier(name), .integer(0))))
      }
    default: break
    }
    return properties
  }

  private func sizeConstraints(base: (Int) -> BExpression, paramNames: [String], count: Int = 0) -> BExpression {
    if paramNames.count == 1 {
      return .and(.greaterThan(base(count), .identifier(paramNames.first!)),
                  .greaterThanOrEqual(.identifier(paramNames.first!), .integer(0)))
    }

    var paramNames = paramNames
    let name = paramNames.remove(at: 0)
    return .and(.and(.greaterThanOrEqual(.identifier(paramNames.first!), .integer(0)),
                     .greaterThan(base(count), .identifier(name))),
                sizeConstraints(base: { .mapRead(base($0), .identifier(name)) }, paramNames: paramNames, count: count + 1))
  }

  private func nestedReads(base: (String) -> BExpression, params: [(String, BType?)], name: String, count: Int = 0) -> BExpression {
    if params.count == 0 {
      return base(name)
    }

    var params = params
    let (paramName, paramType) = params.remove(at: 0)
    let index: BExpression
    if paramType == nil {
      index = .identifier(paramName)
    } else {
      index = .mapRead(base(normaliser.getShadowDictionaryKeysPrefix(depth: count) + name), .identifier(paramName))
    }
    return nestedReads(base: { .mapRead(base($0), index) }, params: params, name: name, count: count + 1)
  }

  private func getDeepDictTypesTilUDT(type: RawType) -> (String, [BType?]) {
    switch type {
    case .dictionaryType(let key, let value):
      let (udt, types) = getDeepDictTypesTilUDT(type: value)
      return (udt, [convertType(key)] + types)
    case .arrayType(let type):
      let (udt, types) = getDeepDictTypesTilUDT(type: type)
      return (udt, [nil] + types)
    case .fixedSizeArrayType(let type, _):
      let (udt, types) = getDeepDictTypesTilUDT(type: type)
      return (udt, [nil] + types)

    // If type is struct then invariant that value < nextInstance
    case .inoutType(.userDefinedType(let udt)), .userDefinedType(let udt):
      return (udt, [])
    default: return ("", [])
    }
  }

  func generateIterableShadowVariables(name: String,
                                       type: RawType,
                                       depth: Int = 0,
                                       declarations: [BVariableDeclaration] = [],
                                       hole: (BType) -> BType = { $0 }) -> [BVariableDeclaration] {
    var declarations = declarations
    switch type {
    case .arrayType(let innerType), .fixedSizeArrayType(let innerType, _):
      // Create size shadow variable
      let shadowName = normaliser.getShadowArraySizePrefix(depth: depth) + name
      declarations.append(BVariableDeclaration(name: shadowName,
                                               rawName: shadowName,
                                               type: hole(.int)))
      return generateIterableShadowVariables(name: name,
                                             type: innerType,
                                             depth: depth + 1,
                                             declarations: declarations,
                                             // arrays are translated to maps
                                             hole: { x in hole(.map(.int, x)) })

    case .dictionaryType(let keyType, let valueType):
      // Dict
      let keyType = convertType(keyType)
      let keysShadowName = normaliser.getShadowDictionaryKeysPrefix(depth: depth) + name
      declarations.append(BVariableDeclaration(name: keysShadowName,
                                               rawName: keysShadowName,
                                               type: hole(.map(.int, keyType))))
      let sizeShadowName = normaliser.getShadowArraySizePrefix(depth: depth) + name
      declarations.append(BVariableDeclaration(name: sizeShadowName,
                                               rawName: sizeShadowName,
                                               type: hole(.int)))
      return generateIterableShadowVariables(name: name,
                                             type: valueType,
                                             depth: depth + 1,
                                             declarations: declarations,
                                             // dictionaries are translated to maps
                                             hole: { x in hole(.map(keyType, x)) })
    default:
      return declarations
    }
  }

  func generateIterableSizeAssumptions(name: String,
                                       type: RawType,
                                       source: SourceLocation,
                                       depth: Int = 0,
                                       isInStruct: Bool = false) -> [BStatement] {
    var assumeStmts = [BStatement]()
    let identifierName = BExpression.identifier(normaliser.getShadowArraySizePrefix(depth: depth) + name)
    let holyDynAccess = nestedIterableAccess(holyExpression: { .greaterThanOrEqual($0, .integer(BigUInt(0))) },
                                             depth: depth,
                                             isInStruct: isInStruct)
    switch type {
    case .dictionaryType(_, let valueType):
      assumeStmts.append(.assume(holyDynAccess(identifierName),
                                 TranslationInformation(sourceLocation: source)))

      assumeStmts += generateIterableSizeAssumptions(name: name, type: valueType, source: source, depth: depth + 1, isInStruct: isInStruct)
    case .arrayType(let valueType):
      assumeStmts.append(.assume(holyDynAccess(identifierName),
                                 TranslationInformation(sourceLocation: source)))
      assumeStmts += generateIterableSizeAssumptions(name: name, type: valueType, source: source, depth: depth + 1, isInStruct: isInStruct)
    case .fixedSizeArrayType(let valueType, let size):
      let holyFixedAccess = nestedIterableAccess(holyExpression: { .equals($0, .integer(BigUInt(size))) },
                                                 depth: depth,
                                                 isInStruct: isInStruct)
      assumeStmts.append(.assume(holyFixedAccess(identifierName),
                                 TranslationInformation(sourceLocation: source)))
      assumeStmts += generateIterableSizeAssumptions(name: name, type: valueType, source: source, depth: depth + 1, isInStruct: isInStruct)
    default: break
    }

    return assumeStmts
  }

  func nestedIterableAccess(holyExpression: @escaping (BExpression) -> BExpression,
                            depth: Int,
                            isInStruct: Bool) -> (BExpression) -> BExpression {
    var isInStruct = isInStruct
    if depth == 0 && isInStruct {
      isInStruct = false
    } else if depth <= 0  && !isInStruct {
      return holyExpression
    }

    let i = "i" + randomString(length: 10)
    return nestedIterableAccess(holyExpression: { .quantified(.forall,
                                                  [BParameterDeclaration(name: i, rawName: i, type: .int)],
                                                  holyExpression(.mapRead($0, .identifier(i)))) } ,
                                depth: depth - 1,
                                isInStruct: isInStruct)
  }

  func getStateVariable() -> String {
    return contractStateVariable[getCurrentTLDName()]!
  }

  func getStateVariableValue(_ identifier: String) -> Int {
    return contractStateVariableStates[getCurrentTLDName()]![identifier]!
  }

  func randomIdentifier(`prefix`: String = "i") -> String {
    return `prefix` + randomString(length: 10) // 10 random characters feels random enough
  }

  func randomString(length: Int) -> String {
      let alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
      var s = ""
      for _ in 0..<length {
        let r = Int.random(in: 0..<alphabet.count)
        s += String(alphabet[alphabet.index(alphabet.startIndex, offsetBy: r)])
      }

    return s
  }

  func generateRandomIdentifier(prefix: String) -> String {
    if let functionName = getCurrentFunctionName() {
      let variableDeclarations = getFunctionVariableDeclarations(name: functionName)
      let returnIdentifier = randomIdentifier(prefix: prefix)

      for declaration in variableDeclarations
        where declaration.name == returnIdentifier {
        return generateRandomIdentifier(prefix: prefix)
      }
      return returnIdentifier
    }
    print("Could not generate function return value name, not currently in function \(prefix)")
    fatalError()
  }

  func getCurrentContractBehaviorDeclaration() -> ContractBehaviorDeclaration? {
    if let tld = currentTLD {
      switch tld {
      case .contractBehaviorDeclaration(let contractBehaviorDeclaration):
        return contractBehaviorDeclaration
      default:
        return nil
      }
    }
    print("Error cannot get current contract declaration - not in any TopLevelDeclaration")
    fatalError()
  }

  func getCurrentTLDName() -> String {
    if let tld = currentTLD {
      switch tld {
      case .contractDeclaration(let contractDeclaration):
        return  contractDeclaration.identifier.name

      case .contractBehaviorDeclaration(let contractBehaviorDeclaration):
        return contractBehaviorDeclaration.contractIdentifier.name
      case .structDeclaration(let structDeclaration):
        return structDeclaration.identifier.name
      case .enumDeclaration(let enumDeclaration):
        return enumDeclaration.identifier.name
      default:
        break
      /*
      TODO: Implement
      case .traitDeclaration(let traitDeclaration):
        */
      }
    }

    print("Error cannot get current contract name: not in a contract")
    fatalError()
  }

  func getCurrentScopeContext() -> ScopeContext? {
    return self.currentScopeContext
  }

  func setCurrentScopeContext(_ ctx: ScopeContext?) -> ScopeContext? {
    let old = self.currentScopeContext
    self.currentScopeContext = ctx
    return old
  }

  func addProcedureCall(_ caller: String, _ callee: String) {
    if self.callGraph[caller] != nil {
      self.callGraph[caller]!.insert(callee)
    } else {
      self.callGraph[caller] = Set<String>([callee])
    }
  }

  func translateIdentifierName(_ name: String, currentFunctionName: String? = nil) -> String {
    if let functionName = currentFunctionName ?? getCurrentFunctionName() {
      // Function name already has contract scope (eg. funcA_ContractA
      return name + "_\(functionName)"
    }
    print("Error cannot translate identifier: \(name), not translating contract")
    fatalError()
  }

  func translateGlobalIdentifierName(_ name: String, enclosingTLD: String? = nil) -> String {
    return name + "_\(enclosingTLD ?? getCurrentTLDName())"
  }

  func convertType(_ type: Type) -> BType {
    return convertType(type.rawType)
  }

  func convertType(_ type: RawType) -> BType {
    func convertBasicType(_ bType: RawType.BasicType) -> BType {
      switch bType {
      case .address: return .userDefined("Address")
      case .int: return .int
      case .bool: return .boolean
      default:
        print("not implemented conversion for basic type: \(type)")
        fatalError()
      }
    }

    func convertStdlibType(_ sType: RawType.StdlibType) -> BType {
      switch sType {
      case .wei:
        return .int
      }
    }

    switch type {
    case .basicType(let basicType):
      return convertBasicType(basicType)
    //case .stdlibType(let stdlibType):
    //  return convertStdlibType(stdlibType)
    case .dictionaryType(let keyType, let valueType):
      return BType.map(convertType(keyType), convertType(valueType))
    case .arrayType(let type):
      return .map(.int, convertType(type))
    case .fixedSizeArrayType(let type, _):
      return .map(.int, convertType(type))
    case .inoutType(let type):
      return convertType(type)
    case .userDefinedType:
      return .int
    case .solidityType(let solidityType):
      guard let flintParallel = solidityType.basicParallel,
            let flintType = RawType.BasicType(rawValue: flintParallel) else {
        print("unkown solidity type to convert to Flint type \(solidityType)")
        fatalError()
      }
      return convertBasicType(flintType)
    default:
      print("not implemented conversion for type: \(type)")
      fatalError()
    }
  }

   func defaultValue(_ type: BType) -> BExpression {
    switch type {
    case .int: return .integer(BigUInt(0))
    case .real: return .real(0, 0)
    case .boolean: return .boolean(false) // TODO: Is this the default bool value?
    case .userDefined: return .integer(BigUInt(0)) //TODO: Is this right, for eg addresses
    //  print("Can't translate default value for user defined type yet \(name)")
    //  fatalError()
    case .map(let t1, let t2):
      if let properties = emptyMapProperties[type] {
        return .functionApplication(properties.2, [])
      }

      let t2Default = defaultValue(t2)
      let emptyMapPropertyName = "Map_\(type.nameSafe).Empty"
      let emptyMapPropertyFunction: BFunctionDeclaration =
      BFunctionDeclaration(name: emptyMapPropertyName,
                           returnType: type,
                           returnName: "result",
                           parameters: [])
      let emptyMapPropertyAxiom: BAxiomDeclaration = BAxiomDeclaration(proposition:
       .quantified(.forall,
                   [BParameterDeclaration(name: "i", rawName: "i", type: t1)],
                   .equals(.mapRead(.functionApplication(emptyMapPropertyName, []), .identifier("i")), t2Default))
      )

      emptyMapProperties[type] = (emptyMapPropertyFunction, emptyMapPropertyAxiom, emptyMapPropertyName)

      return .functionApplication(emptyMapPropertyName, [])
    }
  }
}
