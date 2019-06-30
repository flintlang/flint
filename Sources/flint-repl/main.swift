import Foundation
import Commander
import Diagnostic
import REPL


func main() {
    command (
        Argument<String> ("Contract path", description: "contract to be deployed"),
        Option<String>("address", default: "", description: "The address of an already deployed contract")
    )
    { contractFilePath, address in
        
        let repl = REPL(contractFilePath : contractFilePath, contractAddress : address)
        
        do {
            try repl.run()
        } catch let err {
            print(err)
        }

        }.run()
}

func main_d() throws {
    
    let repl = REPL(contractFilePath : "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/repl_eval/Counter.flint", contractAddress : "")
    do {
        try repl.run()
    } catch let err {
        print(err)
    }
}

main()
//try main_d()
