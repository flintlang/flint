import Foundation
import Commander

func main() {
  command(
    Argument<String>("input file", description: "The input file to compile."),
    Flag("emit-ir", flag: "i", description: "Emit the IULIA internal representation of the code.")
  ) { inputFile, emitIulia in
    let inputFileURL = URL(fileURLWithPath: inputFile)
    let output = Compiler(inputFile: inputFileURL).compile()

    if emitIulia {
      let iuliaFileURL = inputFileURL.deletingPathExtension().appendingPathExtension("sol")
      try! output.write(to: iuliaFileURL, atomically: true, encoding: .utf8)
    }
  }.run()
}

main()
