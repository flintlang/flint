import Foundation
import Commander
import AST
import LSP
import JSTranslator
import Diagnostic

/// The main function for the testing framework
func main() {
    command (
        Argument<String> ("Test file", description: "Test file (.tflint)"),
        Flag("test runner", flag:"t", description:"Flag to run unit tests for test framework")
    )
    { sourceCode, test_run in
        let fileName =  sourceCode
        let inputFiles = [URL(fileURLWithPath: fileName)]
        let sourceCode = try String(contentsOf: inputFiles[0])
        
        do {
            try TestRunner(testFile: inputFiles[0],
                           sourceCode: sourceCode,
                           diagnostics: DiagnosticPool(shouldVerify: false,
                                                       quiet: false,
                                                       sourceContext: SourceContext(sourceFiles: inputFiles)),
                           test_run: test_run).run_tests()
            
        } catch let err {
            print(err)
            print("Failed to run tests")
        }
        
    }.run() 
}

func main_d() throws {
    let fileName = "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/testRunner/test_results/test_flint_contracts/caller_caps.tflint"
    let inputFiles = [URL(fileURLWithPath: fileName)]
    let sourceCode = try String(contentsOf: inputFiles[0])
    
    do {
        try TestRunner(testFile: inputFiles[0],
                       sourceCode: sourceCode,
                       diagnostics: DiagnosticPool(shouldVerify: false,
                                                   quiet: false,
                                                   sourceContext: SourceContext(sourceFiles: inputFiles)),
                       test_run: true).run_tests()
        
    } catch let err {
        print(err)
        print("Failed to run tests")
    }
}

main()

