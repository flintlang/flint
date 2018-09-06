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
    Flag("dump-ast", flag: "a", description: "Print the abstract syntax tree of the code."),
    Flag("verify", flag: "v", description: "Verify expected diagnostics were produced."),
    Flag("quiet", flag: "q", description: "Supress warnings and only emit fatal errors."),
    VariadicArgument<String>("input files", description: "The input files to compile.")
  ) { emitIR, irOutputPath, emitBytecode, dumpAST, shouldVerify, quiet, inputFilePaths in
    let inputFiles = inputFilePaths.map(URL.init(fileURLWithPath:))

    for inputFile in inputFiles {
      guard FileManager.default.fileExists(atPath: inputFile.path), inputFile.pathExtension == "flint" else {
        exitWithFileNotFoundDiagnostic(file: inputFile)
      }
    }

    let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("bin")
    try! FileManager.default.createDirectory(atPath: outputDirectory.path, withIntermediateDirectories: true, attributes: nil)

    let compilationOutcome = Compiler(
      inputFiles: inputFiles,
      stdlibFiles: StandardLibrary.default.files,
      outputDirectory: outputDirectory,
      emitBytecode: emitBytecode,
      diagnostics: DiagnosticPool(shouldVerify: shouldVerify, quiet: quiet, sourceContext: SourceContext(sourceFiles: inputFiles))
    ).compile()

    if emitIR {
      let fileName = "main.sol"
      let irFileURL: URL
      if irOutputPath.isEmpty {
        irFileURL = outputDirectory.appendingPathComponent(fileName)
      } else {
        irFileURL = URL(fileURLWithPath: irOutputPath, isDirectory: true).appendingPathComponent(fileName)
      }
      try! compilationOutcome.irCode.write(to: irFileURL, atomically: true, encoding: .utf8)
    }

    if dumpAST {
      print(compilationOutcome.astDump)
    }
  }.run()
}

func exitWithFileNotFoundDiagnostic(file: URL) -> Never {
  let diagnostic = Diagnostic(severity: .error, sourceLocation: nil, message: "Invalid file: '\(file.path)'.")
  print(DiagnosticsFormatter(diagnostics: [diagnostic], sourceContext: nil).rendered())
  exit(1)
}

func exitWithSolcNotInstalledDiagnostic() -> Never {
  let diagnostic = Diagnostic(
    severity: .error,
    sourceLocation: nil,
    message: "Missing dependency: solc",
    notes: [Diagnostic(severity: .note, sourceLocation: nil, message: "Refer to http://solidity.readthedocs.io/en/develop/installing-solidity.html for installation instructions.")]
  )
  print(DiagnosticsFormatter(diagnostics: [diagnostic], sourceContext: nil).rendered())
  exit(1)
}

main()
