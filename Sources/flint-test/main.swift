import Foundation
import Commander
import AST
import LSP
import JSTranslator
import Diagnostic

/// The main function for the compiler.
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
            
        } catch {
            print("Failed to run tests")
        }
        
    }.run() 
}

func main_d() throws {
    let fileName = "/Users/Zubair/Documents/Imperial/Thesis/Code/flint_testing_framework_older_webjs/examples/test_counter.tflint"
    let inputFiles = [URL(fileURLWithPath: fileName)]
    let sourceCode = try String(contentsOf: inputFiles[0])
    
    do {
        try TestRunner(testFile: inputFiles[0],
                       sourceCode: sourceCode,
                       diagnostics: DiagnosticPool(shouldVerify: false,
                                                   quiet: false,
                                                   sourceContext: SourceContext(sourceFiles: inputFiles)),
                       test_run: false).run_tests()
        
    } catch {
        print("Failed to run tests")
    }
}

//try main_d()
main()
//try main_d()
