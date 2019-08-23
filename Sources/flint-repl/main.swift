import Foundation
import Commander
import Diagnostic
import REPL
import Utils

func main() {
  command(
      Argument<String>("Contract path", description: "contract to be deployed"),
      Option<String>("address", default: "", description: "The address of an already deployed contract")
  ) { contractFilePath, address in

    let repl = REPL(contractFilePath: contractFilePath, contractAddress: address)

    do {
      try repl.run()
    } catch let err {
      print(err)
    }

  }.run()
}

func mainTest() throws {
  let contractFilePath = Path.getFullUrl(path: "examples/valid/counter.flint").path
  print(contractFilePath)
  let repl = REPL(contractFilePath: contractFilePath,
                  contractAddress: "")
  do {
    try repl.run()
  } catch let err {
    print(err)
  }
}

main()
//try mainTest()
