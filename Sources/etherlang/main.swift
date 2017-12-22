import Foundation

func main() {
  let inputFile = CommandLine.arguments[1]
  let output = Compiler(inputFile: URL(fileURLWithPath: inputFile)).compile()
  print(output)
}

main()
