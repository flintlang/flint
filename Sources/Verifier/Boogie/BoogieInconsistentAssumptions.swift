import Diagnostic
import Source

class BoogieInconsistentAssumptions {
  private let monoLocation: String
  private let boogieLocation: String
  private var boogieAst: BTopLevelProgram
  private var procedureMap: [SourceLocation: BProcedureDeclaration]

  init (boogie: BTopLevelProgram, monoLocation: String, boogieLocation: String) {
    self.monoLocation = monoLocation
    self.boogieLocation = boogieLocation
    self.boogieAst = boogie
    self.procedureMap = [:]
  }

  func diagnose() -> [Diagnostic] {
    // Replace body of each procedure with assume false
    // For all the ones which verify, return inconsistent assumption diagnostics

    self.boogieAst = BTopLevelProgram(declarations: self.boogieAst.declarations.map({ replaceProcedureBody($0) }))
    let (boogieSource, boogieMapping) = self.boogieAst.render()

    let boogieErrors = Boogie.verifyBoogie(boogie: boogieSource,
                                           monoLocation: self.monoLocation,
                                           boogieLocation: self.boogieLocation,
                                           printVerificationOutput: false)
    return resolveBoogieErrors(errors: boogieErrors, mapping: boogieMapping)
  }

  private func replaceProcedureBody(_ declaration: BTopLevelDeclaration) -> BTopLevelDeclaration {
    switch declaration {
    case .procedureDeclaration(let procedure):
      let ti = TranslationInformation(sourceLocation: procedure.ti.sourceLocation)
      let assertFalseBody = [BStatement.assertStatement(BAssertStatement(expression: .boolean(false),
                                                                         ti: ti))]
      let replacementProcedure = BProcedureDeclaration(name: procedure.name,
                                                       returnType: procedure.returnType,
                                                       returnName: procedure.returnName,
                                                       parameters: procedure.parameters,
                                                       preConditions: procedure.preConditions,
                                                       postConditions: procedure.postConditions,
                                                       modifies: procedure.modifies,
                                                       statements: assertFalseBody,
                                                       variables: Set<BVariableDeclaration>(),
                                                       ti: procedure.ti)
      self.procedureMap[procedure.ti.sourceLocation] = procedure
      return .procedureDeclaration(replacementProcedure)
    default:
      return declaration
    }
  }

  private func resolveBoogieErrors(errors: [BoogieError], mapping: [Int: TranslationInformation]) -> [Diagnostic] {
    // The procedures which don't have inconsistent assumptions, will throw assertion failures
    var consistentProcedures = Set<SourceLocation>()
    for error in errors {
      switch error {
      case .assertionFailure(let lineNumber):
        guard let ti = mapping[lineNumber] else {
          print(mapping)
          print("Couldn't find translation information for assertion on line \(lineNumber) in inconsistent assertions")
          fatalError()
        }
        consistentProcedures.insert(ti.sourceLocation)

      default:
        // Should only see assertion failures - not calling other functions
        print("Unhandled boogie failure type - inconsistent assumptions")
        fatalError()
      }
    }

    // Find procedures which verified
    let inconsistentProcedures = Set(self.procedureMap.keys).subtracting(consistentProcedures)

    var diagnostics = [Diagnostic]()
    for procedure in inconsistentProcedures {
      let notes = procedureMap[procedure]?.preConditions.map({
                                                               Diagnostic(severity: .note,
                                                                          sourceLocation: $0.ti.sourceLocation,
                                                                          message: "Caused by")
                                                              }) ?? []

      diagnostics.append(Diagnostic(severity: .warning,
                                    sourceLocation: procedure,
                                    message: "This function has inconsistent pre-conditions. It will trivially verify.",
                                    notes: notes))
    }

    return diagnostics
  }
}
