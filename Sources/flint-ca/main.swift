import Foundation
import Commander
import AST
import ContractAnalysis
import Diagnostic
import Utils

/// The main function for the compiler.
func main() {
  command(
      Flag("typestate information", flag: "t", description: "Information for typestates"),
      Flag("caller capability analysis", flag: "c", description: "Information for caller capabilites"),
      Flag("gas estimation", flag: "g", description: "gas estimation of contract and functions"),
      Flag("function analysis", flag: "f", description: "run function analysis"),
      Flag("test harness", flag: "u", description: "run in test harness mode"),
      Argument<String>("source code", description: "source code to verify"),
      Argument<String>("file name", description: "file name")
  ) { typeStateDiagram, callerAnalysis, estimateGas, fA, test_run, sourceCode, fileName in

    do {
      let a = Analyser(contractFile: fileName,
                       sourceCode: sourceCode,
                       estimateGas: estimateGas,
                       typeStateDiagram: typeStateDiagram,
                       callerCapabilityAnalysis: callerAnalysis,
                       isTestRun: test_run,
                       functionAnalysis: fA)
      try a.analyse()

    } catch let err {
      print(err)
    }
  }.run()
}

func mainTest() throws {
  let fileName = Path.getFullUrl(path: "examples/valid/counter.flint").path
  let inputFiles = [Path.getFullUrl(path: "examples/valid/counter.flint")]
  let sourceCode = try String(contentsOf: inputFiles[0])

  do {
    let a = Analyser(contractFile: fileName,
                     sourceCode: sourceCode,
                     estimateGas: true,
                     typeStateDiagram: false,
                     callerCapabilityAnalysis: false,
                     isTestRun: false,
                     functionAnalysis: false)
    try a.analyse()

  } catch let err {
    print(err)
  }
}

//try mainTest()
main()
