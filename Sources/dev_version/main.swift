import Foundation
import Commander
import AST
import LSP
import Diagnostic

/// The main function for the compiler.

func main() {
    let inputFiles : [URL] = [URL(fileURLWithPath:"/Users/Zubair/Documents/Imperial/Thesis/Code/flint/test.flint")]

//    let outDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("bin")
//    do {
//      try FileManager.default.createDirectory(atPath: outputDirectory.path,
//                                              withIntermediateDirectories: true,
//                                              attributes: nil)
//    } catch {
//      exitWithDirectoryNotCreatedDiagnostic(outputDirectory: outputDirectory)
//    }
    
    //let compilationOutcome: CompilationOutcome
    do {
    print("this is the first time running")
      let c = Compiler(
        inputFiles: inputFiles,
        stdlibFiles: StandardLibrary.default.files,
        outputDirectory: URL(string: "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/bin")!,
        dumpAST: false,
        emitBytecode: false,
        diagnostics: DiagnosticPool(shouldVerify: false,
                                    quiet: false,
                                    sourceContext: SourceContext(sourceFiles: inputFiles)))
        
        try c.ide_compile()
        let diag = c.diagnostics
        // I want a line here that converts everything to json inih
        print("hiii")
        try c.diagnostics.display()
        let json = try convertFlintDiagToLspDiagJson(diag.getDiagnostics())
        
        
        print(json)
        
        //LSP.convertFlintDiagToLspDiagJson(diag)
        //print(diag)
    } catch let err {
      let diagnostic = Diagnostic(severity: .error,
                                  sourceLocation: nil,
                                  message: err.localizedDescription)
      // swiftlint:disable force_try
      print(try! DiagnosticsFormatter(diagnostics: [diagnostic], sourceContext: nil).rendered())
      // swiftlint:enable force_try
      exit(1)
    }
}

func exitWithFileNotFoundDiagnostic(file: URL) -> Never {
  let diagnostic = Diagnostic(severity: .error, sourceLocation: nil, message: "Invalid file: '\(file.path)'.")
  // swiftlint:disable force_try
  print(try! DiagnosticsFormatter(diagnostics: [diagnostic], sourceContext: nil).rendered())
  // swiftlint:enable force_try
  exit(1)
}

func exitWithDirectoryNotCreatedDiagnostic(outputDirectory: URL) -> Never {
  let diagnostic = Diagnostic(severity: .error,
                              sourceLocation: nil,
                              message: "Could not create output directory: '\(outputDirectory.path)'.")
  // swiftlint:disable force_try
  print(try! DiagnosticsFormatter(diagnostics: [diagnostic], sourceContext: nil).rendered())
  // swiftlint:enable force_try
  exit(1)
}

func exitWithUnableToWriteIRFile(irFileURL: URL) {
  let diagnostic = Diagnostic(severity: .error,
                              sourceLocation: nil,
                              message: "Could not write IR file: '\(irFileURL.path)'.")
  // swiftlint:disable force_try
  print(try! DiagnosticsFormatter(diagnostics: [diagnostic], sourceContext: nil).rendered())
  // swiftlint:enable force_try
  exit(1)
}

func exitWithSolcNotInstalledDiagnostic() -> Never {
  let diagnostic = Diagnostic(
    severity: .error,
    sourceLocation: nil,
    message: "Missing dependency: solc",
    notes: [
      Diagnostic(
        severity: .note,
        sourceLocation: nil,
        message: "Refer to http://solidity.readthedocs.io/en/develop/installing-solidity.html " +
                 "for installation instructions.")
    ]
  )
  // swiftlint:disable force_try
  print(try! DiagnosticsFormatter(diagnostics: [diagnostic], sourceContext: nil).rendered())
  // swiftlint:enable force_try
  exit(1)
}

main()
