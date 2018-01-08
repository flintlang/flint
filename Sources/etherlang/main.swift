import Foundation
import Commander

func main() {
  command(
    Argument<String>("input file", description: "The input file to compile."),
    Flag("emit-ir", flag: "i", description: "Emit the internal representation of the code."),
    Flag("emit-bytecode", flag: "b", description: "Emit the EVM bytecode representation of the code.")
  ) { inputFile, emitIulia, emitBytecode in
    let inputFileURL = URL(fileURLWithPath: inputFile)
    let fileName = inputFileURL.deletingPathExtension().lastPathComponent
    let outputDirectory = inputFileURL.deletingLastPathComponent().appendingPathComponent("bin/\(fileName)")
    let compilationOutcome = Compiler(inputFile: inputFileURL, outputDirectory: outputDirectory, emitBytecode: emitBytecode).compile()

    if emitIulia {
      let fileName = inputFileURL.deletingPathExtension().lastPathComponent + ".sol"
      let irFileURL = outputDirectory.appendingPathComponent(fileName)
      try! compilationOutcome.irCode.write(to: irFileURL, atomically: true, encoding: .utf8)
    }
  }.run()
}

main()
