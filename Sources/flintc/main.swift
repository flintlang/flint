import Foundation

import AST
import Compiler
import Commander
import Diagnostic

/// The main function for the compiler.
func main() {
  command(
    Flag("emit-ir", flag: "i", description: "Emit the internal representation of the code."),
    Option<String>("ir-output", default: "", description: "The path at which the IR file should be created."),
    Flag("emit-bytecode", flag: "b", description: "Emit the EVM bytecode representation of the code."),
    Flag("dump-verifier-ir", flag: "d", description: "Emit the representation of the code used by the verifier."),
    Flag("print-verifier-output", flag: "o", description: "Emit the verifier's raw verification output"),
    Flag("skip-holistic", flag: "l", description: "Skip checking holistic specifications"),
    Flag("skip-verifier", flag: "s", description: "Skip automatic formal code verification"),
    //TODO: Reached hard limit on # of arguments that Commander supports
    //Flag("print-holistic-run-stats", flag: "r", description: "Emit the holistic verifier's engine's run stats"),
    Option<Int>("holistic-max-timeout", default: 10, description: "Set the max timeout (s) for the holistic verifier"),
    Flag("skip-code-gen", flag: "g", description: "Skip code generation"),
    Flag("dump-ast", flag: "a", description: "Print the abstract syntax tree of the code."),
    Flag("verify", flag: "v", description: "Verify expected diagnostics were produced."),
    Flag("quiet", flag: "q", description: "Supress warnings and only emit fatal errors."),
    Flag("no-stdlib", description: "Do not load the standard library"),
    VariadicArgument<String>("input files", description: "The input files to compile.")
  ) { emitIR, irOutputPath, emitBytecode, dumpVerifierIR, printVerificationOutput, skipHolisticCheck, skipVerifier, /*printHolisticRunStats,*/ maxHolisticTimeout, skipCodeGen, dumpAST, shouldVerify, quiet, noStdlib, inputFilePaths in
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
      let compilerConfig = CompilerConfiguration(
        inputFiles: inputFiles,
        stdlibFiles: StandardLibrary.default.files,
        outputDirectory: outputDirectory,
        dumpAST: dumpAST,
        emitBytecode: emitBytecode,
        dumpVerifierIR: dumpVerifierIR,
        printVerificationOutput: printVerificationOutput,
        skipHolisticCheck: skipHolisticCheck,
        printHolisticRunStats: true, //printHolisticRunStats,
        maxHolisticTimeout: maxHolisticTimeout,
        skipVerifier: skipVerifier,
        skipCodeGen: skipCodeGen,
        diagnostics: DiagnosticPool(shouldVerify: shouldVerify,
                                    quiet: quiet,
                                    sourceContext: SourceContext(sourceFiles: inputFiles)),
        loadStdlib: !noStdlib
        )
      compilationOutcome = try Compiler.compile(config: compilerConfig)
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

main()
