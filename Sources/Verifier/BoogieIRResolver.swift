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

    let mapping = generateFlint2BoogieMapping(code: "\(BTopLevelProgram(declarations: declarations))",
                                              proofObligationMapping: ir.lineMapping)
    return FlintBoogieTranslation(boogieTlds: declarations,
                                  holisticTestProcedures: holisticDeclarations,
                                  holisticTestEntryPoints: ir.holisticTestEntryPoints,
                                  lineMapping: mapping)
  }

  private func resolve(irProcedureDeclaration: BIRProcedureDeclaration) -> BProcedureDeclaration {
    let modifies = self.procedureModifies[irProcedureDeclaration.name] ?? Set<BModifiesDeclaration>()
    return BProcedureDeclaration(name: irProcedureDeclaration.name,
                                 returnType: irProcedureDeclaration.returnType,
                                 returnName: irProcedureDeclaration.returnName,
                                 parameters: irProcedureDeclaration.parameters,
                                 prePostConditions: irProcedureDeclaration.prePostConditions,
                                 modifies: modifies,
                                 statements: irProcedureDeclaration.statements,
                                 variables: irProcedureDeclaration.variables,
                                 mark: irProcedureDeclaration.mark)
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

  private func generateFlint2BoogieMapping(code: String,
                                           proofObligationMapping: [VerifierMappingKey: SourceLocation]) -> [Int: SourceLocation] {
    var mapping = [Int: SourceLocation]()

    let lines = code.trimmingCharacters(in: .whitespacesAndNewlines)
                               .components(separatedBy: "\n")
    var boogieLine = 1 // Boogie starts counting lines from 1
    for line in lines {
      // Pre increment because assert markers precede asserts and pre/post condits
      boogieLine += 1

      // Look for ASSERT markers
      let matches = line.groups(for: "// #MARKER# ([0-9]+) (.*)")
      if matches.count == 1 {
        // Extract line number
        let line = Int(matches[0][1])!
        if line < 0 { //Invalid
          continue
        }

        let file: String = matches[0][2]
        guard let sourceLocation = proofObligationMapping[VerifierMappingKey(file: file, flintLine: line)] else {
          print("Couldn't find marker for proof obligation")
          print(proofObligationMapping)
          print(line)
          print(file)
          fatalError()
        }
        mapping[boogieLine] = sourceLocation
      }
    }
    return mapping
  }
}
