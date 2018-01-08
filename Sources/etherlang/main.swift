import Foundation
import Commander

func main() {
  command(
    Argument<String>("input file", description: "The input file to compile."),
    Flag("emit-ir", flag: "i", description: "Emit the internal representation of the code."),
    Flag("emit-bytecode", flag: "b", description: "Emit the EVM bytecode representation of the code."),
    Flag("dump-ast", flag: "a", description: "Print the abstract syntax tree of the code.")
  ) { inputFile, emitIulia, emitBytecode, dumpAST in
    let inputFileURL = URL(fileURLWithPath: inputFile)
    let fileName = inputFileURL.deletingPathExtension().lastPathComponent
    let outputDirectory = inputFileURL.deletingLastPathComponent().appendingPathComponent("bin/\(fileName)")
    let compilationOutcome = Compiler(inputFile: inputFileURL, outputDirectory: outputDirectory, emitBytecode: emitBytecode).compile()

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

main()
