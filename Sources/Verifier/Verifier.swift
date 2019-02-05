import AST
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

  public func verify() -> (verified: Bool, errors: [String]) {
    let translation = boogieTranslator.translate()
    if dumpVerifierIR {
      print(translation)
    }
    let errors = executeBoogie(boogie: translation)
    return (errors.count == 0, errors)
  }

  private func executeBoogie(boogie: String) -> [String] {

    let uniqueFileName = UUID().uuidString + ".bpl"
    let tempBoogieFile = URL(fileURLWithPath: NSTemporaryDirectory(),
                             isDirectory: true).appendingPathComponent(uniqueFileName)
    do {
      // Safely force unwrap as Swift uses unicode internally
      try boogie.data(using: .utf8)!.write(to: tempBoogieFile, options: [.atomic])
    } catch {
      return ["Error writing boogie to file: \(error)"]
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
      return ["Error during verification, could not decode verifier output"]
    }

    let output = uncheckedOutput!

    if task.terminationStatus != 0 {
      return ["Error during verification, verifier terminated with non-zero exit code", output]
    }

    return extractBoogieErrors(boogieOutput: output)
  }

  private func extractBoogieErrors(boogieOutput: String) -> [String] {
    // TODO: Implement
    // TODO: Searching for error doesn't always work in detecting errors
    // ie: 0 errors were found
    //boogieOutput.range(of: "error") == nil
    return [boogieOutput]
  }
}
// swiftlint:enable all
