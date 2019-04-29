import Foundation
import Commander
import AST
import ContractAnalysis
import Diagnostic

/// The main function for the compiler.
func main() {
    command (
        Flag("typestate information", flag:"t", description:"Information for typestates"),
        Flag("caller capability analysis", flag:"c", description:"Information for caller capabilites"),
        Flag("gas estimation", flag:"g", description:"gas estimation of contract and functions"),
        Argument<String> ("source code", description: "source code to verify"),
        Argument<String> ("file name", description: "file name")
    )
    { typeStateDiagram, callerAnalysis, estimateGas, sourceCode, fileName in
        
        do {
            let a = Analyser(contractFile: fileName,
                             sourceCode: sourceCode,
                             estimateGas: estimateGas,
                             typeStateDiagram: typeStateDiagram,
                             callerCapabilityAnalysis: callerAnalysis)
            try a.analyse()
            
        } catch let err {
            print(err)
        }
    }.run() 
}

func main_d() throws {
        let fileName = "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/ide_examples/curr_examples/test.flint"
        let inputFiles = [URL(fileURLWithPath: fileName)]
        let sourceCode = try String(contentsOf: inputFiles[0])
    
        do {
             let a = Analyser(contractFile: fileName,
                         sourceCode: sourceCode,
                         estimateGas: true,
                         typeStateDiagram: false,
                         callerCapabilityAnalysis: false)
             try a.analyse()
        
        } catch let err {
          print(err)
        }
}

try main_d()
//main()
