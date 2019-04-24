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
  private let maxHolisticTimeout: Int
  private var boogieTranslator: BoogieTranslator

  public init(dumpVerifierIR: Bool,
              printVerificationOutput: Bool,
              skipHolisticCheck: Bool,
              printHolisticRunStats: Bool,
              boogieLocation: String,
              symbooglixLocation: String,
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
    self.maxHolisticTimeout = maxHolisticTimeout
    self.boogieTranslator = BoogieTranslator(topLevelModule: topLevelModule,
                                             environment: environment,
                                             sourceContext: sourceContext,
                                             normaliser: normaliser)
  }

  // Verify flint code and return flint line number and suggestion for any error
  public func verify() -> (verified: Bool, errors: [Diagnostic]) {
    // Returns the boogie translation and a mapping from Boogie line #'s to flint line #'s
    let translationIR = boogieTranslator.translate()
    let translation = BoogieIRResolver().resolve(ir: translationIR)
    let (functionalBoogieSource, functionalMapping) = translation.functionalProgram.render()
    if self.dumpVerifierIR {
      print(functionalBoogieSource)
    }

    // Verify boogie code
    let boogieErrors = executeBoogie(boogie: functionalBoogieSource)
    let flintErrors = resolveBoogieErrors(errors: boogieErrors, mapping: functionalMapping)
    let functionalVerification = boogieErrors.count == 0

    // Test holistic spec
    var holisticErrors = [Diagnostic]()
    var holisticVerification = true
    if functionalVerification && !skipHolisticCheck && translation.holisticTestEntryPoints.count > 0 {
      for holisticRunInfo in executeSymbooglix(translation: translation,
                                               maxTimeout: self.maxHolisticTimeout) {
        holisticVerification = holisticVerification && holisticRunInfo.verified
        if let diagnostic = diagnoseRunInfo(holisticRunInfo: holisticRunInfo,
                                            printHolisticRunStats: self.printHolisticRunStats) {
          holisticErrors.append(diagnostic)
        }
      }
    }

    return (functionalVerification && holisticVerification, flintErrors + holisticErrors)
  }

  private func executeBoogie(boogie: String) -> [BoogieError] {
    let tempBoogieFile = writeToTempFile(data: boogie)
    let (uncheckedOutput, terminationStatus) = executeTask(executable: monoLocation,
                                                           arguments: [boogieLocation, tempBoogieFile.path])
    guard let output = uncheckedOutput else {
      print("Error during verification, could not decode verifier output")
      fatalError()
    }

    if printVerificationOutput {
      print(output)
    }

    if terminationStatus != 0 {
      print("Error during verification, verifier terminated with non-zero exit code")
      print(output)
      fatalError()
    }

    return extractBoogieErrors(rawBoogieOutput: output)
  }

  private func executeSymbooglix(translation: FlintBoogieTranslation, maxTimeout: Int) -> [HolisticRunInfo] {
    var runInfo = [HolisticRunInfo]()
    for (holisticSpec, holisticProgram) in translation.holisticPrograms {
      let (holisticBoogieSource, _) = holisticProgram.render()

      let tempHolisticFile = writeToTempFile(data: holisticBoogieSource)
      let entryPoints = translation.holisticTestEntryPoints.joined(separator: ",")
      let workingDir = NSTemporaryDirectory() + UUID().uuidString
      let arguments = [symbooglixLocation, tempHolisticFile.path,
        "--timeout", String(maxTimeout),
        "--output-dir", workingDir,
        "-e", entryPoints]
      let (uncheckedOutput, terminationStatus) = executeTask(executable: monoLocation,
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

  private func executeTask(executable: String, arguments: [String]) -> (String?, Int32) {
    // Create a Task instance
    let task = Process()

    // Set the task parameters
    task.launchPath = executable
    task.arguments = arguments

    // Create a Pipe and make the task
    // put all the output there
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()

    // Launch the task
    task.launch()
    task.waitUntilExit()

    // Get the data
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let uncheckedOutput = String(data: data, encoding: String.Encoding.utf8)
    return (uncheckedOutput, task.terminationStatus)
  }

  private func writeToTempFile(data: String) -> URL {
    let uniqueFileName = UUID().uuidString + ".bpl"
    let tempFile = URL(fileURLWithPath: NSTemporaryDirectory(),
                             isDirectory: true).appendingPathComponent(uniqueFileName)
    do {
      // Safely force unwrap as Swift uses unicode internally
      try data.data(using: .utf8)!.write(to: tempFile, options: [.atomic])
    } catch {
      print("Error writing boogie to file: \(error)")
      fatalError()
    }
    return tempFile
  }

  private func extractSymbooglixErrors(terminationCountersFile: String, spec: SourceLocation) -> HolisticRunInfo {
    do {
      let results = try Yaml.load(try String(contentsOf: URL(fileURLWithPath: terminationCountersFile),
                                             encoding: .utf8))
      guard let resultDict = results.dictionary else {
        print("Found no results in termination_counters file")
        fatalError()

      }
      let successfulRuns = resultDict["TerminatedWithoutError"]!.int!
      let totalRuns = resultDict.reduce(0, { $0 + $1.value.int!})
      return HolisticRunInfo(totalRuns: totalRuns,
                             successfulRuns: successfulRuns,
                             responsibleSpec: spec)
    } catch {
      print("Unable to parse termination_counters yaml file")
      fatalError()
    }
  }

  private func extractBoogieErrors(rawBoogieOutput: String) -> [BoogieError] {
    // Example Boogie output
    /*
    Boogie program verifier version 2.3.0.61016, Copyright (c) 2003-2014, Microsoft.
    test.bpl(472,3): Error BP5002: A precondition for this call might not hold.
    test.bpl(461,3): Related location: This is the precondition that might not hold.
    Execution trace:
        test.bpl(472,3): anon0
    test.bpl(482,1): Error BP5003: A postcondition might not hold on this return path.
    test.bpl(477,3): Related location: This is the postcondition that might not hold.
    Execution trace:
        test.bpl(481,5): anon0
    test.bpl(492,1): Error BP5003: A postcondition might not hold on this return path.
    test.bpl(487,3): Related location: This is the postcondition that might not hold.
    Execution trace:
        test.bpl(491,5): anon0
    test.bpl(498,3): Error BP5001: This assertion might not hold.
    Execution trace:
        test.bpl(498,3): anon0
    test.bpl(508,3): Error BP5002: A precondition for this call might not hold.
    test.bpl(461,3): Related location: This is the precondition that might not hold.
    Execution trace:
        test.bpl(507,5): anon0

    test.bpl(364,1): Error BP5004: This loop invariant might not hold on entry.
    Execution trace:
        test.bpl(313,23): anon0
        test.bpl(329,30): anon15_Then
        test.bpl(334,19): anon3
        test.bpl(344,30): anon16_Then
        test.bpl(349,22): anon6
        test.bpl(351,1): anon17_LoopHead
        test.bpl(357,22): anon17_LoopBody

    Boogie program verifier finished with 13 verified, 5 errors


    935-ADAC-1E81E2A8A081.bpl(209,0): Error: command assigns to a global variable that is not in the enclosing procedure's modifies clause: nextInstance_Wei

    Boogie program verifier finished with 10 verified, 1 error


    */
    var rawLines = rawBoogieOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                               .components(separatedBy: "\n")
    rawLines.removeFirst() // Discard first line - contains Boogie version info

    // Check if output contains non-verification errors (syntax ...)

    var nonVerificationErrors = [BoogieError]()
    for line in rawLines {
      let matches = line.groups(for: "\\([0-9]+,[0-9]+\\): [eE]rror:")
      if matches.count > 0 {
        if line.contains("modifies clause") {
          nonVerificationErrors.append(.modifiesFailure(line))
        } else {
          nonVerificationErrors.append(.genericFailure(line))
        }
      }
    }
    if nonVerificationErrors.count > 0 {
      return nonVerificationErrors
    }

    var groupedErrorLines = [(Int, [String])]() // Error code + trace
    for line in rawLines {
      // Look for tuple followed by "Error BP...."
      let matches = line.groups(for: "\\([0-9]+,[0-9]+\\): Error BP([0-9]+)")
      if matches.count > 0 {
        groupedErrorLines.append((Int(matches[0][1])!, []))
      }

      if groupedErrorLines.count > 0 {
        groupedErrorLines[groupedErrorLines.count-1].1.append(line)
      }
    }

    return groupedErrorLines.map({ parseBoogieError(errorCode: $0.0, errorLines: $0.1) })
  }

  private func parseBoogieError(errorCode: Int, errorLines: [String]) -> BoogieError {
    switch errorCode {
    case 5001:
      // Assertion failure
      guard let firstLine = errorLines.first else {
        print("Assertion failure should have at least one line")
        fatalError()
      }
      let lineNumber = parseErrorLineNumber(line: firstLine)
      return .assertionFailure(lineNumber)

    case 5002:
      // Precondition failure
      let callLocationLine = errorLines[0] // Line of procedure call
      let callLineNumber = parseErrorLineNumber(line: callLocationLine)

      let relatedLocationLine = errorLines[1] // Related location line, has the offending pre condition
      let preCondLineNumber = parseErrorLineNumber(line: relatedLocationLine)
      return .preConditionFailure(callLineNumber, preCondLineNumber)

    case 5003:
      // PostCondition failure
      let relatedLocationLine = errorLines[1] // Related location line, has the offending post condition
      let postCondLineNumber = parseErrorLineNumber(line: relatedLocationLine)

      let procedureResponsibleLine = errorLines[0] // Has the line of the responsible return path of offending procedure
      let procedureResponsibleLineNumber = parseErrorLineNumber(line: procedureResponsibleLine)
      return .postConditionFailure(procedureResponsibleLineNumber, postCondLineNumber)

    case 5004:
      let loopInvariantLine = errorLines[0] // Has the line of the responsible return path of offending procedure
      let loopInvariantLineNumber = parseErrorLineNumber(line: loopInvariantLine)
      return .loopInvariantEntryFailure(loopInvariantLineNumber)

    default:
      print("Couldn't determine type of verification failure code: \(errorCode)\n\(errorLines)")
      fatalError()
    }
  }

  private func parseErrorLineNumber(line: String) -> Int {
    // Look for tuple followed by "Error"
    let matches = line.groups(for: "\\(([0-9]+),[0-9]+\\):")
    switch matches.count {
    case 1:
      // Extract line number
      return Int(matches[0][1])!
    default:
      print("Could not parse boogie error line")
      print(matches)
      print(line)
      fatalError()
    }
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

extension String {
  func groups(for regexPattern: String) -> [[String]] {
    do {
      let text = self
      let regex = try NSRegularExpression(pattern: regexPattern)
      let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
      return matches.map { match in
        return (0..<match.numberOfRanges).map {
          let rangeBounds = match.range(at: $0)
          guard let range = Range(rangeBounds, in: text) else {
            return ""
          }
        return String(text[range])
        }
      }
    } catch let error {
      print("invalid regex: \(error.localizedDescription)")
      return []
    }
  }
}

