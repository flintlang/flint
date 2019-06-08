import Diagnostic
import Source

import Dispatch

class BoogieUnreachableCode {
  private let monoLocation: String
  private let boogieLocation: String
  private var boogieAst: BTopLevelProgram

  struct Info {
    let sourceLocation: SourceLocation
    let trueCase: Bool // condition is always true
  }

  init (boogie: BTopLevelProgram, monoLocation: String, boogieLocation: String) {
    self.monoLocation = monoLocation
    self.boogieLocation = boogieLocation
    self.boogieAst = boogie
  }

  func diagnose() -> [Diagnostic] {
    // Replace body of each procedure with assume false
    // For all the ones which verify, return inconsistent assumption diagnostics

    let generatedCombinations = generateIfConditionCombinations(tlp: self.boogieAst)
    var verifierInfo = Array(repeating: ([BoogieError](), [Int: TranslationInformation](), Info(sourceLocation: SourceLocation.DUMMY, trueCase: false)),
                             count: generatedCombinations.count)
    let parVerify: (Int) -> Void = { index in
      let (program, target) = generatedCombinations[index]
      let (boogieSource, boogieMapping) = program.render()
      let boogieErrors = Boogie.verifyBoogie(boogie: boogieSource,
                                             monoLocation: self.monoLocation,
                                             boogieLocation: self.boogieLocation,
                                             printVerificationOutput: false)
      verifierInfo[index] = (boogieErrors, boogieMapping, target)
    }
    DispatchQueue.concurrentPerform(iterations: generatedCombinations.count, execute: parVerify)
    return resolveBoogieErrors(verifierInfo: verifierInfo)
  }

  private func generateIfConditionCombinations(tlp: BTopLevelProgram) -> [(BTopLevelProgram, Info)] {
    //TODO: These loop ordering are wrong, don't need to make a new program for each declaration
    var programs = [(BTopLevelProgram, Info)]()
    for index in 0..<tlp.declarations.count {
      var oldProgramDeclarations = tlp.declarations

      for (declaration, info) in processDeclaration(oldProgramDeclarations.remove(at: index)) where info != nil {
        var newProgramDeclarations = oldProgramDeclarations
        newProgramDeclarations.insert(declaration, at: index)

        programs.append((BTopLevelProgram(declarations: newProgramDeclarations), info!))
      }
    }
    return programs
  }

  private func processDeclaration(_ declaration: BTopLevelDeclaration) -> [(BTopLevelDeclaration, Info?)] {
    switch declaration {
    case .procedureDeclaration(let bProcedureDeclaration):
      return processProcedureDeclaration(bProcedureDeclaration).map({ (.procedureDeclaration($0), $1) })
    default: return [(declaration, nil)]
    }
  }

  private func processProcedureDeclaration(_ procedureDeclaration: BProcedureDeclaration) -> [(BProcedureDeclaration, Info)] {
    let statements = procedureDeclaration.statements

    var procedures = [(BProcedureDeclaration, Info)]()
    for index in 0..<statements.count {
      var oldStatements = statements

      for (statement, info) in processStatement(oldStatements.remove(at: index)) where info != nil {
        var newStatements = oldStatements
        newStatements.insert(statement, at: index)

        procedures.append((BProcedureDeclaration(
          name: procedureDeclaration.name,
          returnTypes: procedureDeclaration.returnTypes,
          returnNames: procedureDeclaration.returnNames,
          parameters: procedureDeclaration.parameters,
          preConditions: procedureDeclaration.preConditions,
          postConditions: procedureDeclaration.postConditions,
          modifies: procedureDeclaration.modifies,
          statements: newStatements,
          variables: procedureDeclaration.variables,
          inline: procedureDeclaration.inline,
          ti: procedureDeclaration.ti), info!))
      }
    }
    return procedures
  }

  private func processStatement(_ statement: BStatement) -> [(BStatement, Info?)] {
    switch statement {
    case .ifStatement(let bIfStatement):
      return processIfStatement(bIfStatement).map({ ($0, $1) })
    case .whileStatement(let whileLoop):
      return processWhileLoop(whileLoop).map({ (.whileStatement($0), $1) })
    default: return [(statement, nil)]
    }
  }

  private func processWhileLoop(_ whileLoop: BWhileStatement) -> [(BWhileStatement, Info)] {
    var whileStatements = [(BWhileStatement, Info)]()

    for index in 0..<whileLoop.body.count {
      var oldStatements = whileLoop.body

      for (statement, info) in processStatement(oldStatements.remove(at: index)) where info != nil {
        var newStatements = oldStatements
        newStatements.insert(statement, at: index)

        whileStatements.append((BWhileStatement(condition: whileLoop.condition,
                                                body: newStatements,
                                                invariants: whileLoop.invariants,
                                                ti: whileLoop.ti), info!))
      }
    }

    return whileStatements
  }

  private func processIfStatement(_ bIfStatement: BIfStatement) -> [(BStatement, Info)] {
    var ifStatements = [(BIfStatement, Info)]()

    for index in 0..<bIfStatement.trueCase.count {
      var oldStatements = bIfStatement.trueCase

      for (statement, info) in processStatement(oldStatements.remove(at: index)) where info != nil {
        var newStatements = oldStatements
        newStatements.insert(statement, at: index)

        ifStatements.append((BIfStatement(condition: bIfStatement.condition,
                                         trueCase: newStatements,
                                         falseCase: bIfStatement.falseCase,
                                         ti: bIfStatement.ti), info!))
      }
    }

    for index in 0..<bIfStatement.falseCase.count {
      var oldStatements = bIfStatement.falseCase

      for (statement, info) in processStatement(oldStatements.remove(at: index)) where info != nil {
        var newStatements = oldStatements
        newStatements.insert(statement, at: index)

        ifStatements.append((BIfStatement(condition: bIfStatement.condition,
                                         trueCase: bIfStatement.trueCase,
                                         falseCase: newStatements,
                                         ti: bIfStatement.ti), info!))
      }
    }

    var testCondition = [(BStatement, Info)]()
    if bIfStatement.ti.isUserDirectCause {
      let slt = Info(sourceLocation: bIfStatement.ti.sourceLocation, trueCase: true)
      let slf = Info(sourceLocation: bIfStatement.ti.sourceLocation, trueCase: false)
      testCondition += [(.assertStatement(BAssertStatement(expression: bIfStatement.condition,
                                                           ti: bIfStatement.ti)), slt),
                        (.assertStatement(BAssertStatement(expression: .not(bIfStatement.condition),
                                                           ti: bIfStatement.ti)), slf)
      ]
    }
    return testCondition + ifStatements.map({ (.ifStatement($0), $1) })
  }

  private func resolveBoogieErrors(verifierInfo: [([BoogieError], [Int: TranslationInformation], Info)]) -> [Diagnostic] {
    // The if statements which don't have unreachable code, will throw assertion failures
    var unreachableCode = [Info]()
    for (errors, mapping, targettedCondition) in verifierInfo {
      var passed = true
      for error in errors {
        switch error {
        case .assertionFailure(let lineNumber):
          guard let ti = mapping[lineNumber] else {
            print(mapping)
            print("Couldn't find translation information for assertion on line \(lineNumber) in unreachable code")
            fatalError()
          }
          passed = passed && ti.sourceLocation != targettedCondition.sourceLocation

        default:
          // Other failures may happen, but we're not interested in those.
          break
        }
      }

      if passed {
        unreachableCode.append(targettedCondition)
      }
    }

    var diagnostics = [Diagnostic]()
    for info in unreachableCode {
      let caseMsg = info.trueCase ? "The condition is always true" : "The condition is always false"
      diagnostics.append(Diagnostic(severity: .warning,
                                    sourceLocation: info.sourceLocation,
                                    message: "This statement has unreachable code. " + caseMsg,
                                    notes: []))
    }

    return diagnostics
  }
}
