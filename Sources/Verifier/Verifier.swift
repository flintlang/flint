import AST
import Diagnostic
import Foundation

public class Verifier: ASTPass {
  public init() {}

  public func process(contractBehaviorDeclaration: ContractBehaviorDeclaration,
                      passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {
    let diagnostics = [Diagnostic]()
    let environment = passContext.environment!

    return ASTPassResult(element: contractBehaviorDeclaration, diagnostics: diagnostics, passContext: passContext)
  }

  public func postProcess(contractBehaviorDeclaration: ContractBehaviorDeclaration,
                          passContext: ASTPassContext) -> ASTPassResult<ContractBehaviorDeclaration> {

    executeBoogie(monoLocation: "/usr/bin/mono",
                  boogieLocation: "boogie/Binaries/Boogie.exe",
                  bplFileLocation: "examples/casestudies/Bank.bpl")

    return ASTPassResult(element: contractBehaviorDeclaration, diagnostics: [], passContext: passContext)
  }

  private func executeBoogie(monoLocation: String, boogieLocation: String, bplFileLocation: String) {
    // Create a Task instance
    let task = Process()

    // Set the task parameters
    task.launchPath = monoLocation
    task.arguments = [boogieLocation, bplFileLocation]

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
      // TODO: Throw error - and show to user
    }

    let output = uncheckedOutput!

    if task.terminationStatus != 0 {
      // TODO: throw error
      print(output)
    }

    if output.range(of: "error") == nil { // TODO: Doesn't work in detecting errors ie: 0 errors were found
      print("Verified")
    } else {
      print("Not verified")
    }
  }
}
// swiftlint:enable all
