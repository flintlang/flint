import AST
import Source
import Lexer
import Diagnostic
import Foundation

public class Verifier {
  private let boogieLocation: String
  private let monoLocation: String
  private let dumpVerifierIR: Bool
  private var boogieTranslator: BoogieTranslator

  public init(dumpVerifierIR: Bool, boogieLocation: String,
              monoLocation: String, topLevelModule: TopLevelModule,
              environment: Environment) {
    self.boogieLocation = boogieLocation
    self.monoLocation = monoLocation
    self.dumpVerifierIR = dumpVerifierIR
    self.boogieTranslator = BoogieTranslator(topLevelModule: topLevelModule,
                                             environment: environment)
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

        Boogie program verifier finished with 10 verified, 1 error

    */
    var lines = rawBoogieOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                               .components(separatedBy: "\n")
    lines.removeFirst() // Discard first line - contains Boogie version info

    var errors = [BoogieError]()
    for line in lines {
      // Look for tuple followed by "Error"
      let matches = line.groups(for: "\\(([0-9]+),[0-9]+\\): Error")
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
      return .assertionFailure(lineNumber, line)

    } else if line.contains("precondition") {
      return .assertionFailure(lineNumber, line)
    }

    print("Couldn't determine type of verification failure: \(line)")
    fatalError()
  }

  private func resolveBoogieErrors(errors boogieErrors: [BoogieError],
                                   mapping b2fSourceMapping: [Int: SourceLocation]) -> [Diagnostic] {

    var flintErrors = [Diagnostic]()
    for error in boogieErrors {
      switch error {
      case .assertionFailure(let line, _):
        flintErrors.append(Diagnostic(severity: .error,
                                      sourceLocation: b2fSourceMapping[line]!,
                                      message: "Could not verify assertion holds"))
      //TODO: Need to determine if it's an 'invariant' error, or actual user
      // supplied pre/post condition failure
      case .preConditionFailure(let line, _):
        flintErrors.append(Diagnostic(severity: .error,
                                      sourceLocation: b2fSourceMapping[line]!,
                                      message: "Could not verify pre-condition holds"))
      case .postConditionFailure(let line, _):
        flintErrors.append(Diagnostic(severity: .error,
                                      sourceLocation: b2fSourceMapping[line]!,
                                      message: "Could not verify post-condition holds"))
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
