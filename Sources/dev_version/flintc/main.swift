import Foundation
import Commander
import AST
import Diagnostic

/// The main function for the compiler.

func main() {
    let inputFiles = [URL(string: "sd")]

    let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("bin")
    do {
      try FileManager.default.createDirectory(atPath: outputDirectory.path,
                                              withIntermediateDirectories: true,
                                              attributes: nil)
    } catch {
      exitWithDirectoryNotCreatedDiagnostic(outputDirectory: outputDirectory)
    }
    
    if lsp {
        let x = Compiler(
            inputFiles: inputFiles,
            stdlibFiles: StandardLibrary.default.files,
            outputDirectory: outputDirectory,
            dumpAST: dumpAST,
            emitBytecode: emitBytecode,
            diagnostics: DiagnosticPool(shouldVerify: shouldVerify,
                                        quiet: quiet,
                                        sourceContext: SourceContext(sourceFiles: inputFiles))
            ).lsp_compile()
        print("{test: \"dsfs\", test1: \"ddsfds\"}")
        exit(0)
    }

    let compilationOutcome: CompilationOutcome
    do {
      compilationOutcome = try Compiler(
        inputFiles: inputFiles,
        stdlibFiles: StandardLibrary.default.files,
        outputDirectory: outputDirectory,
        dumpAST: dumpAST,
        emitBytecode: emitBytecode,
        diagnostics: DiagnosticPool(shouldVerify: shouldVerify,
                                    quiet: quiet,
                                    sourceContext: SourceContext(sourceFiles: inputFiles))
      ).compile()
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
