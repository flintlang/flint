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
    examples/casestudies/Bank.bpl(260,1): Error BP5003: A postcondition might not hold on this return path.
    examples/casestudies/Bank.bpl(249,3): Related location: This is the postcondition that might not hold.
    Execution trace:
        examples/casestudies/Bank.bpl(251,15): anon0

    test.bpl(186,1): Error BP5001: This assertion might not hold.
    Execution trace:
       test.bpl(186,1): anon0

    bank_test.bpl(4,64): error: invalid Function

    F7DA4749-9924-4C41-972A-8EBF33398B69.bpl(234,1): Error BP5002: A precondition for this call might not hold.
    F7DA4749-9924-4C41-972A-8EBF33398B69.bpl(292,1): Related location: This is the precondition that might not hold.

    935-ADAC-1E81E2A8A081.bpl(209,0): Error: command assigns to a global variable that is not in the enclosing procedure's modifies clause: nextInstance_Wei
    2853A8A3-FF61-4575-95A3-36516B26A887.bpl(317,1): Error BP5004: This loop invariant might not hold on entry.

    Boogie program verifier finished with 10 verified, 1 error
    */
    var rawLines = rawBoogieOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                               .components(separatedBy: "\n")
    rawLines.removeFirst() // Discard first line - contains Boogie version info

    var groupedErrorLines = [(BoogieError, [String])]()
    for line in rawLines {
      // Look for tuple followed by "Error BP...."
      let matches = line.groups(for: "\\(([0-9]+),([0-9]+)\\): Error BP[0-9]+")
      if matches.count > 0 {
        groupedErrorLines.append((.assertionFailure(0, ""), []))
      }

      if groupedErrorLines.count > 0 {
        groupedErrorLines[groupedErrorLines.count-1].1.append(line)
      }
    }

    for errorGroup in groupedErrorLines {
      // get the failing condition - inv / pre / post / assert
      let failingCondition = errorGroup.removeFirst()

      // get which function it's failing in - inv + pre + post

      // get callee function, if exists called by whom? - inv + pre
      // TODO: Execution Trace
    }

    var errors = [BoogieError]()
    for line in rawLines {
      // Look for tuple followed by "Error"
      let matches = line.groups(for: "\\(([0-9]+),[0-9]+\\): (Error (BP[0-9]+)|Related location|Error:|error:)")
      switch matches.count {
      case 0:
        break
      case 1:
        // Extract line number
        errors.append(parseBoogieError(lineNumber: Int(matches[0][1])!,
                                       error: line))
      default:
        print(matches)
        print("was expecting 3 matches on last line of Boogie output")
        print(rawBoogieOutput)
        fatalError()
      }
    }

    return errors
  }

  private func parseBoogieError(lineNumber: Int, error line: String) -> BoogieError {
    if line.contains("assertion") {
      return .assertionFailure(lineNumber, line)

    } else if line.contains("postcondition") {
      return .postConditionFailure(lineNumber, line)

    } else if line.contains("precondition for this call might not hold") {
      return .callPreConditionFailure(lineNumber, line)

    } else if line.contains("This is the precondition that might not hold") {
      return .preConditionFailure(lineNumber, line)

    } else if line.contains("global variable that is not in the enclosing procedure's modifies clause") {
      return .modifiesFailure(lineNumber, line)

    } else if line.contains("loop invariant might not hold on entry") {
      return .loopInvariantEntryFailure(lineNumber, line)

    } else if line.contains("loop invariant might not be maintained by the loop") {
      return .loopInvariantMaintenanceFailure(lineNumber, line)
    }

    print("Couldn't determine type of verification failure: \(line)")
    fatalError()
  }

  private func resolveBoogieErrors(errors boogieErrors: [BoogieError],
                                   mapping b2fSourceMapping: [Int: SourceLocation]) -> [Diagnostic] {

    var flintErrors = [Diagnostic]()
    for error in boogieErrors {
      switch error {
      case .assertionFailure(let lineNumber, _):
        guard let sourceLocation = b2fSourceMapping[lineNumber] else {
          print("cannot find mapping for failing proof obligation on line \(lineNumber)")
          fatalError()
        }
        flintErrors.append(Diagnostic(severity: .error,
                                      sourceLocation: sourceLocation,
                                      message: "Could not verify assertion holds"))
      case .callPreConditionFailure(let lineNumber, _):
        guard let sourceLocation = b2fSourceMapping[lineNumber] else {
          print("cannot find mapping for failing proof obligation on line \(lineNumber)")
          fatalError()
        }
        flintErrors.append(Diagnostic(severity: .error,
                                      sourceLocation: sourceLocation,
                                      message: "Could not verify pre-condition for this call holds"))
      case .preConditionFailure(let lineNumber, _):
        guard let sourceLocation = b2fSourceMapping[lineNumber] else {
          print("cannot find mapping for failing proof obligation on line \(lineNumber)")
          fatalError()
        }
        flintErrors.append(Diagnostic(severity: .error,
                                      sourceLocation: sourceLocation,
                                      message: "Could not verify pre-condition holds"))
      case .postConditionFailure(let lineNumber, _):
        guard let sourceLocation = b2fSourceMapping[lineNumber] else {
          print("cannot find mapping for failing proof obligation on line \(lineNumber)")
          fatalError()
        }
        flintErrors.append(Diagnostic(severity: .error,
                                      sourceLocation: sourceLocation,
                                      message: "Could not verify post-condition holds"))
      case .modifiesFailure(let lineNumber, let line):
        print("modifies failure - on line \(lineNumber): \(line)")
        //guard let sourceLocation = b2fSourceMapping[lineNumber] else {
        //  print("cannot find mapping for failing proof obligation on line \(lineNumber)")
        //  fatalError()
        //}
        // TODO: Determine if this is a shadow variable or a user variable - display enclosing function sourceLocation
        //flintErrors.append(Diagnostic(severity: .error,
        //                              sourceLocation: sourceLocation,
        //                              message: "Could not verify post-condition holds"))
        continue
      case .loopInvariantEntryFailure(let lineNumber, let line):
        guard let sourceLocation = b2fSourceMapping[lineNumber] else {
          print("cannot find mapping for failing proof obligation on line \(lineNumber)")
          fatalError()
        }
        flintErrors.append(Diagnostic(severity: .error,
                                      sourceLocation: sourceLocation,
                                      message: "Could not verify entry to the loop \(line)"))
      case .loopInvariantMaintenanceFailure(let lineNumber, let line):
        guard let sourceLocation = b2fSourceMapping[lineNumber] else {
          print("cannot find mapping for failing proof obligation on line \(lineNumber)")
          fatalError()
        }
        flintErrors.append(Diagnostic(severity: .error,
                                      sourceLocation: sourceLocation,
                                      message: "Could not verify loop body \(line)"))
      }
    }
    return flintErrors
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
