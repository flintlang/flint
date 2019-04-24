import Source

class BoogieIRResolver: IRResolver {
  typealias InputType = BoogieTranslationIR
  typealias ResultType = FlintBoogieTranslation

  // Mapping from procedure name to variables it modifies
  var procedureModifies = [String: Set<BModifiesDeclaration>]()

  func resolve(ir: BoogieTranslationIR) -> FlintBoogieTranslation {
    // Process mutates clause - flow non-user-defined mutates
    var procedureDeclarations = [BIRProcedureDeclaration]()
    for case .procedureDeclaration(let dec) in (ir.tlds + ir.holisticTestProcedures) {
      procedureDeclarations.append(dec)
    }
    self.procedureModifies = resolveMutates(callGraph: ir.callGraph, procedureDeclarations: procedureDeclarations)

    var declarations = [BTopLevelDeclaration]()
    for declaration in ir.tlds {
      switch declaration {
      case .functionDeclaration(let bFunctionDeclaration):
        declarations.append(BTopLevelDeclaration.functionDeclaration(bFunctionDeclaration))
      case .axiomDeclaration(let bAxiomDeclaration):
        declarations.append(BTopLevelDeclaration.axiomDeclaration(bAxiomDeclaration))
      case .variableDeclaration(let bVariableDeclaration):
        declarations.append(BTopLevelDeclaration.variableDeclaration(bVariableDeclaration))
      case .constDeclaration(let bConstDeclaration):
        declarations.append(BTopLevelDeclaration.constDeclaration(bConstDeclaration))
      case .typeDeclaration(let bTypeDeclaration):
        declarations.append(BTopLevelDeclaration.typeDeclaration(bTypeDeclaration))
      case .procedureDeclaration(let bIRProcedureDeclaration):
        declarations.append(.procedureDeclaration(resolve(irProcedureDeclaration: bIRProcedureDeclaration)))
      }
    }

    var holisticDeclarations = [BTopLevelDeclaration]()
    for declaration in ir.holisticTestProcedures {
      switch declaration {
      case .functionDeclaration(let bFunctionDeclaration):
        holisticDeclarations.append(BTopLevelDeclaration.functionDeclaration(bFunctionDeclaration))
      case .axiomDeclaration(let bAxiomDeclaration):
        holisticDeclarations.append(BTopLevelDeclaration.axiomDeclaration(bAxiomDeclaration))
      case .variableDeclaration(let bVariableDeclaration):
        holisticDeclarations.append(BTopLevelDeclaration.variableDeclaration(bVariableDeclaration))
      case .constDeclaration(let bConstDeclaration):
        holisticDeclarations.append(BTopLevelDeclaration.constDeclaration(bConstDeclaration))
      case .typeDeclaration(let bTypeDeclaration):
        holisticDeclarations.append(BTopLevelDeclaration.typeDeclaration(bTypeDeclaration))
      case .procedureDeclaration(let bIRProcedureDeclaration):
        holisticDeclarations.append(.procedureDeclaration(resolve(irProcedureDeclaration: bIRProcedureDeclaration)))
      }
    }

    return FlintBoogieTranslation(boogieTlds: declarations,
                                  holisticTestProcedures: holisticDeclarations,
                                  holisticTestEntryPoints: ir.holisticTestEntryPoints)
  }

  private func resolve(irProcedureDeclaration: BIRProcedureDeclaration) -> BProcedureDeclaration {
    let modifies = self.procedureModifies[irProcedureDeclaration.name] ?? Set<BModifiesDeclaration>()

    // Resolve invariants -> convert into pre+post
    var preConditions = irProcedureDeclaration.preConditions
    var postConditions = irProcedureDeclaration.postConditions

    for invariant in irProcedureDeclaration.structInvariants {
      // Add pre and post, even for struct inits, because nextInstance will have incremented for inits
      preConditions.append(BPreCondition(expression: invariant.expression, ti: invariant.ti))
      postConditions.append(BPostCondition(expression: invariant.expression, ti: invariant.ti))
    }

    for invariant in irProcedureDeclaration.contractInvariants + irProcedureDeclaration.globalInvariants {
      if !irProcedureDeclaration.isContractInit {
        preConditions.append(BPreCondition(expression: invariant.expression, ti: invariant.ti))
      }
      postConditions.append(BPostCondition(expression: invariant.expression, ti: invariant.ti))
    }

    return BProcedureDeclaration(name: irProcedureDeclaration.name,
                                 returnType: irProcedureDeclaration.returnType,
                                 returnName: irProcedureDeclaration.returnName,
                                 parameters: irProcedureDeclaration.parameters,
                                 preConditions: preConditions,
                                 postConditions: postConditions,
                                 modifies: modifies,
                                 statements: irProcedureDeclaration.statements,
                                 variables: irProcedureDeclaration.variables,
                                 ti: irProcedureDeclaration.ti)
  }

  private func resolveMutates(callGraph: [String: Set<String>],
                              procedureDeclarations: [BIRProcedureDeclaration]) -> [String: Set<BModifiesDeclaration>] {

    var modifies = Dictionary(uniqueKeysWithValues: procedureDeclarations.map({ ($0.name, $0.modifies) }))
    var procedureInfo = Dictionary(uniqueKeysWithValues: procedureDeclarations.map({ ($0.name, $0) }))

    // Make enough iterations for modifies to flow through all procedures
    for _ in 0...procedureDeclarations.count {
      for (currentProcedure, called) in callGraph {
        var calleeModifies = Set<BIRModifiesDeclaration>()
        let isCurrentProcedureHolistic = procedureInfo[currentProcedure]?.isHolisticProcedure ?? false
        for calledProcedure in called {
          let eligibleModifies = modifies[calledProcedure]?.filter({ isCurrentProcedureHolistic || !$0.userDefined })
          calleeModifies = calleeModifies.union(eligibleModifies ?? Set())
        }
        modifies[currentProcedure] = modifies[currentProcedure]?.union(calleeModifies) ?? Set()
      }
    }
    return modifies.mapValues({ Set<BModifiesDeclaration>($0.map({ BModifiesDeclaration(variable: $0.variable) })) })
  }
}
