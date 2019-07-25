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

func main_d() throws {

  let repl = REPL(contractFilePath: Path.getFullUrl(path: "repl_eval/Counter.flint").absoluteString,
                  contractAddress: "")
  do {
    try repl.run()
  } catch let err {
    print(err)
  }
}

main()
//try main_d()
