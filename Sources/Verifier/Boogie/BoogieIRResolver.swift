import Source

class BoogieIRResolver: IRResolver {
  typealias InputType = BoogieTranslationIR
  typealias ResultType = FlintBoogieTranslation

  // Mapping from procedure name to variables it modifies
  var procedureModifies = [String: Set<BModifiesDeclaration>]()

  func resolve(ir: BoogieTranslationIR) -> FlintBoogieTranslation {
    // Process mutates clause - flow non-user-defined mutates
    var procedureDeclarations = [BIRProcedureDeclaration]()
    for case .procedureDeclaration(let dec) in (ir.tlds + ir.holisticTestProcedures.flatMap({ $0.1 })) {
      // Don't insert duplicate copies of procedures - due to holistic creation of SelectFunction + CallableFunctions
      if !procedureDeclarations.contains(where: { $0.name == dec.name }) {
        procedureDeclarations.append(dec)
      }
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

    var holisticDeclarations = [(SourceLocation, [BTopLevelDeclaration])]()
    for (spec, declarations) in ir.holisticTestProcedures {
      var tlds = [BTopLevelDeclaration]()
      for declaration in declarations {
        switch declaration {
        case .functionDeclaration(let bFunctionDeclaration):
          tlds.append(BTopLevelDeclaration.functionDeclaration(bFunctionDeclaration))
        case .axiomDeclaration(let bAxiomDeclaration):
          tlds.append(BTopLevelDeclaration.axiomDeclaration(bAxiomDeclaration))
        case .variableDeclaration(let bVariableDeclaration):
          tlds.append(BTopLevelDeclaration.variableDeclaration(bVariableDeclaration))
        case .constDeclaration(let bConstDeclaration):
          tlds.append(BTopLevelDeclaration.constDeclaration(bConstDeclaration))
        case .typeDeclaration(let bTypeDeclaration):
          tlds.append(BTopLevelDeclaration.typeDeclaration(bTypeDeclaration))
        case .procedureDeclaration(let bIRProcedureDeclaration):
          tlds.append(.procedureDeclaration(resolve(irProcedureDeclaration: bIRProcedureDeclaration)))
        }
      }

      holisticDeclarations.append((spec, tlds))
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
                                 returnTypes: irProcedureDeclaration.returnTypes,
                                 returnNames: irProcedureDeclaration.returnNames,
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
