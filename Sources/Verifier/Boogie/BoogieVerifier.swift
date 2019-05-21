import AST
import Source
import Lexer
import Diagnostic
import Foundation

import Yaml

public class BoogieVerifier: Verifier {
  private let boogieLocation: String
  private let symbooglixLocation: String
  private let monoLocation: String
  private let dumpVerifierIR: Bool
  private let printVerificationOutput: Bool
  private let printHolisticRunStats: Bool
  private let skipHolisticCheck: Bool
  private let maxTransactionDepth: Int
  private let maxHolisticTimeout: Int
  private var boogieTranslator: BoogieTranslator

  public init(dumpVerifierIR: Bool,
              printVerificationOutput: Bool,
              skipHolisticCheck: Bool,
              printHolisticRunStats: Bool,
              boogieLocation: String,
              symbooglixLocation: String,
              maxTransactionDepth: Int,
              maxHolisticTimeout: Int,
              monoLocation: String,
              topLevelModule: TopLevelModule,
              environment: Environment,
              sourceContext: SourceContext,
              normaliser: IdentifierNormaliser) {
    self.boogieLocation = boogieLocation
    self.symbooglixLocation = symbooglixLocation
    self.monoLocation = monoLocation
    self.dumpVerifierIR = dumpVerifierIR
    self.printVerificationOutput = printVerificationOutput
    self.skipHolisticCheck = skipHolisticCheck
    self.printHolisticRunStats = printHolisticRunStats
    self.maxTransactionDepth = maxTransactionDepth
    self.maxHolisticTimeout = maxHolisticTimeout
    self.boogieTranslator = BoogieTranslator(topLevelModule: topLevelModule,
                                             environment: environment,
                                             sourceContext: sourceContext,
                                             normaliser: normaliser)
  }

  // Verify flint code and return flint line number and suggestion for any error
  public func verify() -> (verified: Bool, errors: [Diagnostic]) {
    // Returns the boogie translation and a mapping from Boogie line #'s to flint line #'s
    let translationIR = boogieTranslator.translate(holisticTransactionDepth: self.maxTransactionDepth)
    let translation = BoogieIRResolver().resolve(ir: translationIR)
    let (functionalBoogieSource, functionalMapping) = translation.functionalProgram.render()
    if self.dumpVerifierIR {
      print(functionalBoogieSource)
    }

    // Verify boogie code
    let boogieErrors = Boogie.verifyBoogie(boogie: functionalBoogieSource,
                                           monoLocation: self.monoLocation,
                                           boogieLocation: self.boogieLocation,
                                           printVerificationOutput: self.printVerificationOutput)
    let flintErrors = resolveBoogieErrors(errors: boogieErrors, mapping: functionalMapping)
    let functionalVerification = boogieErrors.count == 0

    // Check for inconsistent assumptions
    let inconsistentAssumptions = BoogieInconsistentAssumptions(boogie: translation.functionalProgram,
                                                                monoLocation: self.monoLocation,
                                                                boogieLocation: self.boogieLocation).diagnose()

    // Check for unreachable code
    let unreachableCode = BoogieUnreachableCode(boogie: translation.functionalProgram,
                                                monoLocation: self.monoLocation,
                                                boogieLocation: self.boogieLocation).diagnose()

    // Test holistic spec
    var holisticErrors = [Diagnostic]()
    var holisticVerification = true
    if functionalVerification && !skipHolisticCheck && translation.holisticTestEntryPoints.count > 0 {
      for holisticRunInfo in executeSymbooglix(translation: translation,
                                               maxTimeout: self.maxHolisticTimeout,
                                               transactionDepth: self.maxTransactionDepth) {
        holisticVerification = holisticVerification && holisticRunInfo.verified
        if let diagnostic = diagnoseRunInfo(holisticRunInfo: holisticRunInfo,
                                            printHolisticRunStats: self.printHolisticRunStats) {
          holisticErrors.append(diagnostic)
        }
      }
    }

    let verified = functionalVerification && holisticVerification
    let verificationDiagnostics = flintErrors
                                + inconsistentAssumptions
                                + unreachableCode
                                + holisticErrors

    return (verified, verificationDiagnostics)
  }

  private func executeSymbooglix(translation: FlintBoogieTranslation,
                                 maxTimeout: Int,
                                 transactionDepth: Int) -> [HolisticRunInfo] {
    var runInfo = [HolisticRunInfo]()
    for ((holisticSpec, holisticProgram), entryPoint) in zip(translation.holisticPrograms, translation.holisticTestEntryPoints) {
      let (holisticBoogieSource, _) = holisticProgram.render()

      let tempHolisticFile = Boogie.writeToTempFile(data: holisticBoogieSource)
      let workingDir = NSTemporaryDirectory() + UUID().uuidString
      let arguments = [symbooglixLocation, tempHolisticFile.path,
        "--timeout", String(maxTimeout),
        "--output-dir", workingDir,
        "-e", entryPoint]
      let (uncheckedOutput, _) = Boogie.executeTask(executable: monoLocation,
                                                                  arguments: arguments)
      if uncheckedOutput == nil {
        print("Symbooglix produced no output")
        fatalError()
      }

      // exit code 4 == timeout
      //if !(terminationStatus == 4 || terminationStatus == 0) {
      //  print("Symbooglix exited with error code \(terminationStatus)\n\(output)")
      //  fatalError()
      //}
      //print(uncheckedOutput!)
      runInfo.append(extractSymbooglixErrors(terminationCountersFile: workingDir + "/termination_counters.yml",
                                             spec: holisticSpec))
    }
    return runInfo
  }

  private func diagnoseRunInfo(holisticRunInfo: HolisticRunInfo, printHolisticRunStats: Bool) -> Diagnostic? {
    if holisticRunInfo.verified {
      return nil
    }

    var notes = [Diagnostic]()
    if printHolisticRunStats {
      notes.append(Diagnostic(severity: .warning,
                              sourceLocation: SourceLocation.DUMMY,
                              message: """
                                 Number of runs: \(holisticRunInfo.totalRuns)
                                 Number of successes: \(holisticRunInfo.successfulRuns)
                                 Number of failures: \(holisticRunInfo.failedRuns)
                              """))
    }
    return Diagnostic(severity: .error,
                      sourceLocation: holisticRunInfo.responsibleSpec,
                      message: "This holistic spec could not be verified",
                      notes: notes)
  }

  private func extractSymbooglixErrors(terminationCountersFile: String, spec: SourceLocation) -> HolisticRunInfo {
    guard let contents = try? String(contentsOf: URL(fileURLWithPath: terminationCountersFile),
                                     encoding: .utf8) else {
      print("Couldn't get contents of terminationCounters file")
      print(terminationCountersFile)
      fatalError()
    }
    guard let results = try? Yaml.load(contents) else {
      print("Unable to parse termination_counters yaml file")
      print(contents)
      fatalError()
    }

    guard let resultDict = results.dictionary else {
      print("Found no results in termination_counters file")
      fatalError()

    }
    let successfulRuns = resultDict["TerminatedWithoutError"]!.int!
    let totalRuns = resultDict.reduce(0, { $0 + $1.value.int!})
    return HolisticRunInfo(totalRuns: totalRuns,
                           successfulRuns: successfulRuns,
                           responsibleSpec: spec)
  }

  private func diagnoseFailingPreCondition(_ procTi: TranslationInformation,
                                           _ preCondTi: TranslationInformation) -> Diagnostic {

    let failingItem = preCondTi.isInvariant ? "invariant" : "pre-condition"
    let triggerResponsible = preCondTi.triggerName == nil ? "" : "Caused by \(preCondTi.triggerName!) trigger"
    let errorMsg = "Could not verify "
                 + failingItem
                 + " holds on function call"

    return Diagnostic(severity: .error,
                      sourceLocation: procTi.sourceLocation,
                      message: errorMsg,
                      notes: [
                        Diagnostic(severity: .warning,
                                   sourceLocation: preCondTi.sourceLocation,
                                   message: "This is the failing \(failingItem)\n\(triggerResponsible)")
                      ])
  }

  private func diagnoseFailingPostCondition(_ procTi: TranslationInformation,
                                            _ postCondTi: TranslationInformation) -> Diagnostic {

    let failingItem = postCondTi.isInvariant ? "invariant" : "post-condition"
    let triggerResponsible = postCondTi.triggerName == nil ? "" : "Caused by \(postCondTi.triggerName!) trigger"
    let errorMsg = "Could not verify "
                 + failingItem
                 + " holds by end of function"

    return Diagnostic(severity: .error,
                      sourceLocation: procTi.sourceLocation,
                      message: errorMsg,
                      notes: [
                        Diagnostic(severity: .warning,
                                   sourceLocation: postCondTi.sourceLocation,
                                   message: "This is the failing \(failingItem).\n\(triggerResponsible)")
                      ])
  }

  private func diagnoseFailingAssertion(_ ti: TranslationInformation) -> Diagnostic {
    let defaultMessage: String
    if ti.isExternalCall {
      defaultMessage = "Could not verify safe call to external function"
    } else {
      defaultMessage = "Could not verify assertion holds"
    }

    let errorMsg = ti.failingMsg ?? defaultMessage

    var notes = [Diagnostic]()
    if let relatedTI = ti.relatedTI {
      notes.append(Diagnostic(severity: .warning,
                              sourceLocation: relatedTI.sourceLocation,
                              message: "This is the failing property"))
    }

    return Diagnostic(severity: .error,
                      sourceLocation: ti.sourceLocation,
                      message: errorMsg,
                      notes: notes)
  }

  private func resolveBoogieErrors(errors boogieErrors: [BoogieError],
                                   mapping b2fSourceMapping: [Int: TranslationInformation]) -> [Diagnostic] {
    var flintErrors = [Diagnostic]()
    for error in boogieErrors {
      switch error {
      case .assertionFailure(let lineNumber):
        flintErrors.append(diagnoseFailingAssertion(lookupTranslationInformation(line: lineNumber, mapping: b2fSourceMapping)))

      case .preConditionFailure(let procedureCallLine, let preConditionLine):
        flintErrors.append(diagnoseFailingPreCondition(lookupTranslationInformation(line: procedureCallLine, mapping: b2fSourceMapping),
                                                       lookupTranslationInformation(line: preConditionLine, mapping: b2fSourceMapping)))

      case .postConditionFailure(let procedureLine, let postLine):
        flintErrors.append(diagnoseFailingPostCondition(lookupTranslationInformation(line: procedureLine, mapping: b2fSourceMapping),
                                                       lookupTranslationInformation(line: postLine, mapping: b2fSourceMapping)))

      case .loopInvariantEntryFailure(let invariantLine):
        let invariantTi = lookupTranslationInformation(line: invariantLine, mapping: b2fSourceMapping)
        let errorMsg = invariantTi.failingMsg ?? "Could not verify entry to the loop"
        flintErrors.append(Diagnostic(severity: .error,
                                      sourceLocation: invariantTi.sourceLocation,
                                      message: errorMsg))

      case .modifiesFailure(let line):
        print("Missing modifies clause: \(line)")

      case .genericFailure(let line):
        print("Boogie error: \(line)")

    //  case .loopInvariantMaintenanceFailure(let lineNumber, let line):
    //    guard let sourceLocation = b2fSourceMapping[lineNumber] else {
    //      print("cannot find mapping for failing proof obligation on line \(lineNumber)")
    //      fatalError()
    //    }
    //    flintErrors.append(Diagnostic(severity: .error,
    //                                  sourceLocation: sourceLocation,
    //                                  message: "Could not verify loop body \(line)"))
      }
    }
    return flintErrors
  }

  private func lookupTranslationInformation(line: Int, mapping: [Int: TranslationInformation]) -> TranslationInformation {
    guard let translationInformation = mapping[line] else {
      print("cannot find mapping for failing proof obligation on line \(line)")
      fatalError()
    }
    return translationInformation
  }
}
// swiftlint:enable all
