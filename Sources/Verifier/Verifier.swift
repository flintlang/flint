import AST
import Source
import Lexer
import Diagnostic
import Foundation

public class Verifier {
  private let boogieLocation: String
  private let monoLocation: String
  private let dumpVerifierIR: Bool
  private let printVerificationOutput: Bool
  private var boogieTranslator: BoogieTranslator

  public init(dumpVerifierIR: Bool,
              printVerificationOutput: Bool,
              boogieLocation: String,
              monoLocation: String,
              topLevelModule: TopLevelModule,
              environment: Environment,
              sourceContext: SourceContext,
              normaliser: IdentifierNormaliser) {
    self.boogieLocation = boogieLocation
    self.monoLocation = monoLocation
    self.dumpVerifierIR = dumpVerifierIR
    self.printVerificationOutput = printVerificationOutput
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
    let boogieErrors = executeBoogie(boogie: translation)
    let flintErrors = resolveBoogieErrors(errors: boogieErrors, mapping: mapping)
    return (boogieErrors.count == 0, flintErrors)
  }

  private func executeBoogie(boogie: String) -> [BoogieError] {

    let uniqueFileName = UUID().uuidString + ".bpl"
    let tempBoogieFile = URL(fileURLWithPath: NSTemporaryDirectory(),
                             isDirectory: true).appendingPathComponent(uniqueFileName)
    do {
      // Safely force unwrap as Swift uses unicode internally
      try boogie.data(using: .utf8)!.write(to: tempBoogieFile, options: [.atomic])
    } catch {
      print("Error writing boogie to file: \(error)")
      fatalError()
    }

    // Create a Task instance
    let task = Process()

    // Set the task parameters
    task.launchPath = monoLocation
    task.arguments = [boogieLocation, tempBoogieFile.path]

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
    if uncheckedOutput == nil {
      print("Error during verification, could not decode verifier output")
      fatalError()
    }

    let output = uncheckedOutput!
    if printVerificationOutput {
      print(output)
    }

    if task.terminationStatus != 0 {
      print("Error during verification, verifier terminated with non-zero exit code")
      print(output)
      fatalError()
    }

    return extractBoogieErrors(rawBoogieOutput: output)
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

    Boogie program verifier finished with 13 verified, 5 errors


    935-ADAC-1E81E2A8A081.bpl(209,0): Error: command assigns to a global variable that is not in the enclosing procedure's modifies clause: nextInstance_Wei
    2853A8A3-FF61-4575-95A3-36516B26A887.bpl(317,1): Error BP5004: This loop invariant might not hold on entry.

    Boogie program verifier finished with 10 verified, 1 error


    */
    var rawLines = rawBoogieOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                               .components(separatedBy: "\n")
    rawLines.removeFirst() // Discard first line - contains Boogie version info

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
      print(procedureResponsibleLineNumber)
      print(postCondLineNumber)

      return .postConditionFailure(procedureResponsibleLineNumber, postCondLineNumber)
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
    //  case .modifiesFailure(let lineNumber, let line):
    //    print("modifies failure - on line \(lineNumber): \(line)")
    //    //guard let sourceLocation = b2fSourceMapping[lineNumber] else {
    //    //  print("cannot find mapping for failing proof obligation on line \(lineNumber)")
    //    //  fatalError()
    //    //}
    //    // TODO: Determine if this is a shadow variable or a user variable - display enclosing function sourceLocation
    //    //flintErrors.append(Diagnostic(severity: .error,
    //    //                              sourceLocation: sourceLocation,
    //    //                              message: "Could not verify post-condition holds"))
    //    continue
    //  case .loopInvariantEntryFailure(let lineNumber, let line):
    //    guard let sourceLocation = b2fSourceMapping[lineNumber] else {
    //      print("cannot find mapping for failing proof obligation on line \(lineNumber)")
    //      fatalError()
    //    }
    //    flintErrors.append(Diagnostic(severity: .error,
    //                                  sourceLocation: sourceLocation,
    //                                  message: "Could not verify entry to the loop \(line)"))
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
