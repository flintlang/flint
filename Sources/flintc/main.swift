import Foundation
import Commander
import AST

func main() {
  command(
    Argument<String>("input file", description: "The input file to compile."),
    Flag("emit-ir", flag: "i", description: "Emit the internal representation of the code."),
    Flag("emit-bytecode", flag: "b", description: "Emit the EVM bytecode representation of the code."),
    Flag("dump-ast", flag: "a", description: "Print the abstract syntax tree of the code."),
    Flag("verify", flag: "v", description: "Verify expected diagnostics were produced.")
  ) { inputFile, emitIulia, emitBytecode, dumpAST, shouldVerify in
    let inputFileURL = URL(fileURLWithPath: inputFile)

    guard FileManager.default.fileExists(atPath: inputFile) else {
      printFileNotFoundDiagnostic(file: inputFileURL)
      exit(1)
    }

    let fileName = inputFileURL.deletingPathExtension().lastPathComponent
    let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("bin/\(fileName)")
    try! FileManager.default.createDirectory(atPath: outputDirectory.path, withIntermediateDirectories: true, attributes: nil)
    let compilationOutcome = Compiler(inputFile: inputFileURL, outputDirectory: outputDirectory, emitBytecode: emitBytecode, shouldVerify: shouldVerify).compile()

    if emitIulia {
      let fileName = inputFileURL.deletingPathExtension().lastPathComponent + ".sol"
      let irFileURL = outputDirectory.appendingPathComponent(fileName)
      try! compilationOutcome.irCode.write(to: irFileURL, atomically: true, encoding: .utf8)
    }

    if dumpAST {
      print(compilationOutcome.astDump)
    }
  }.run()
}

func printFileNotFoundDiagnostic(file: URL) {
  let diagnostic = Diagnostic(severity: .error, sourceLocation: nil, message: "No such file: '\(file.path)'.")
  print(DiagnosticsFormatter(diagnostics: [diagnostic], compilationContext: nil).rendered())
}

main()
