import Foundation
import Commander
import AST
import Diagnostic

/// The main function for the compiler.
func main() {
  command(
    Flag("emit-ir", flag: "i", description: "Emit the internal representation of the code."),
    Option<String>("ir-output", default: "", description: "The path at which the IR file should be created."),
    Flag("emit-bytecode", flag: "b", description: "Emit the EVM bytecode representation of the code."),
    Flag("dump-verifier-ir", flag: "d", description: "Emit the representation of the code used by the verifier."),
    Flag("print-verification-output", flag: "o", description: "Emit the verifie's raw verification output"),
    Flag("skip-verifier", flag: "s", description: "Skip automatic formal code verification"),
    Flag("dump-ast", flag: "a", description: "Print the abstract syntax tree of the code."),
    Flag("verify", flag: "v", description: "Verify expected diagnostics were produced."),
    Flag("quiet", flag: "q", description: "Supress warnings and only emit fatal errors."),
    VariadicArgument<String>("input files", description: "The input files to compile.")
  ) { emitIR, irOutputPath, emitBytecode, dumpVerifierIR, printVerificationOutput, skipVerifier, dumpAST, shouldVerify, quiet, inputFilePaths in
    let inputFiles = inputFilePaths.map(URL.init(fileURLWithPath:))

    for inputFile in inputFiles {
      guard FileManager.default.fileExists(atPath: inputFile.path), inputFile.pathExtension == "flint" else {
        exitWithFileNotFoundDiagnostic(file: inputFile)
      }
    }

    let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("bin")
    do {
      try FileManager.default.createDirectory(atPath: outputDirectory.path,
                                              withIntermediateDirectories: true,
                                              attributes: nil)
    } catch {
      exitWithDirectoryNotCreatedDiagnostic(outputDirectory: outputDirectory)
    }

    let compilationOutcome: CompilationOutcome
    do {
      compilationOutcome = try Compiler(
        inputFiles: inputFiles,
        stdlibFiles: StandardLibrary.default.files,
        outputDirectory: outputDirectory,
        dumpAST: dumpAST,
        emitBytecode: emitBytecode,
        dumpVerifierIR: dumpVerifierIR,
        printVerificationOutput: printVerificationOutput,
        skipVerifier: skipVerifier,
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

    if emitIR {
      let fileName = "main.sol"
      let irFileURL: URL
      if irOutputPath.isEmpty {
        irFileURL = outputDirectory.appendingPathComponent(fileName)
      } else {
        irFileURL = URL(fileURLWithPath: irOutputPath, isDirectory: true).appendingPathComponent(fileName)
      }
      do {
        try compilationOutcome.irCode.write(to: irFileURL, atomically: true, encoding: .utf8)
      } catch {
        exitWithUnableToWriteIRFile(irFileURL: irFileURL)
      }
    }
  }.run()
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
