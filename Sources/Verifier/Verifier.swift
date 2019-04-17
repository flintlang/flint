import AST
import Source
import Lexer
import Diagnostic
import Foundation

public class Verifier {
  private let boogieLocation: String
  private let symbooglixLocation: String
  private let monoLocation: String
  private let dumpVerifierIR: Bool
  private let printVerificationOutput: Bool
  private let skipHolisticCheck: Bool
  private var boogieTranslator: BoogieTranslator

  public init(dumpVerifierIR: Bool,
              printVerificationOutput: Bool,
              skipHolisticCheck: Bool,
              boogieLocation: String,
              symbooglixLocation: String,
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
    self.boogieTranslator = BoogieTranslator(topLevelModule: topLevelModule,
                                             environment: environment,
                                             sourceContext: sourceContext,
                                             normaliser: normaliser)
  }

  // Verify flint code and return flint line number and suggestion for any error
  public func verify() -> (verified: Bool, errors: [Diagnostic]) {
    // Returns the boogie translation and a mapping from Boogie line #'s to flint line #'s
    let (translation, mapping) = boogieTranslator.translate()
    if dumpVerifierIR {
      print(translation)
    }

    // Verify boogie code
    let boogieErrors = executeBoogie(boogie: "\(translation)")
    let flintErrors = resolveBoogieErrors(errors: boogieErrors, mapping: mapping)
    let contractVerified = boogieErrors.count == 0

    if contractVerified && !skipHolisticCheck {
      let holisticErrors = executeSymbooglix(translation: translation)
    }

    return (contractVerified, flintErrors)
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

  private func executeSymbooglix(translation: FlintBoogieTranslation) -> [BoogieError] {
    let tempHolisticFile = writeToTempFile(data: "\(translation.holisticProgram)")
    let entryPoints = translation.holisticTestEntryPoints.reduce("", { "\($0),\($1)" })
    let arguments = [symbooglixLocation, tempHolisticFile.path, "--timeout", "10", "-e"] + entryPoints
    print(arguments)
    let (uncheckedOutput, terminationStatus) = executeTask(executable: monoLocation,
                                                           arguments: arguments)
    return []
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

  private func resolveBoogieErrors(errors boogieErrors: [BoogieError],
                                   mapping b2fSourceMapping: [Int: SourceLocation]) -> [Diagnostic] {
    var flintErrors = [Diagnostic]()
    for error in boogieErrors {
      switch error {
      case .assertionFailure(let lineNumber):
        let sourceLocation = lookupSourceLocation(line: lineNumber, mapping: b2fSourceMapping)
        flintErrors.append(Diagnostic(severity: .error,
                                      sourceLocation: sourceLocation,
                                      message: "Could not verify assertion holds"))

      case .preConditionFailure(let procedureCallLine, let preConditionLine):
        let procSourceLocation = lookupSourceLocation(line: procedureCallLine, mapping: b2fSourceMapping)
        let preCondSourceLocation = lookupSourceLocation(line: preConditionLine, mapping: b2fSourceMapping)
        flintErrors.append(Diagnostic(severity: .error,
                                      sourceLocation: procSourceLocation,
                                      message: "Could not verify pre-condition on holds",
                                      notes: [
                                        Diagnostic(severity: .warning,
                                                   sourceLocation: preCondSourceLocation,
                                                   message: "This is the failing pre-condition")
                                      ]))

      case .postConditionFailure(let procedureLine, let postLine):
        let procSourceLocation = lookupSourceLocation(line: procedureLine, mapping: b2fSourceMapping)
        let postSourceLocation = lookupSourceLocation(line: postLine, mapping: b2fSourceMapping)
        flintErrors.append(Diagnostic(severity: .error,
                                      sourceLocation: procSourceLocation,
                                      message: "Could not verify function post-condition",
                                      notes: [
                                        Diagnostic(severity: .warning,
                                                   sourceLocation: postSourceLocation,
                                                   message: "This is the post-condition responsible")
                                      ]))
      case .loopInvariantEntryFailure(let invariantLine):
        let invariantSourceLocation = lookupSourceLocation(line: invariantLine, mapping: b2fSourceMapping)
        flintErrors.append(Diagnostic(severity: .error,
                                      sourceLocation: invariantSourceLocation,
                                      message: "Could not verify entry to the loop"))

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

  private func lookupSourceLocation(line: Int, mapping: [Int: SourceLocation]) -> SourceLocation {
    guard let sourceLocation = mapping[line] else {
      print("cannot find mapping for failing proof obligation on line \(line)")
      fatalError()
    }
    return sourceLocation
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
