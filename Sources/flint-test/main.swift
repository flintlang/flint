import Foundation
import Commander
import AST
import LSP
import JSTranslator
import Diagnostic

/// The main function for the compiler.
func main() {
    command (
        Flag("typestate information", flag:"t", description:"Information for typestates"),
        Argument<String> ("source code", description: "source code to verify"),
        Argument<String> ("file name", description: "file name")
    )
    { typeStateDiagram, sourceCode, fileName in
        let inputFiles = [URL(fileURLWithPath: fileName)]
        do {
            let c = Compiler(
                sourceFiles: inputFiles,
                sourceCode: sourceCode,
                stdlibFiles: StandardLibrary.default.files,
                diagnostics: DiagnosticPool(shouldVerify: false,
                                            quiet: false,
                        sourceContext: SourceContext(sourceFiles:inputFiles, sourceCodeString: sourceCode, isForServer: true)),
                typeStateDiagram: typeStateDiagram)
            
            // I need a better way of representing the flags
            try c.ide_compile()
            
        } catch let err {
            let diagnostic = Diagnostic(severity: .error,
                                        sourceLocation: nil,
                                        message: err.localizedDescription)
            // swiftlint:disable force_try
            print(try! DiagnosticsFormatter(diagnostics: [diagnostic], sourceContext: nil).rendered())
            // swiftlint:enable force_try
            exit(1)
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
                                                   sourceContext: SourceContext(sourceFiles: inputFiles))).run_tests()
        
    } catch {
        print("Failed to run tests")
    }
}

//try main_d()
try main_d()
