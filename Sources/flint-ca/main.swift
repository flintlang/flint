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
        let inputFiles = [URL(fileURLWithPath: fileName)]
        do {
            let c = Compiler(
                sourceFiles: inputFiles,
                sourceCode: sourceCode,
                stdlibFiles: StandardLibrary.default.files,
                diagnostics: DiagnosticPool(shouldVerify: false,
                                            quiet: false,
                        sourceContext: SourceContext(sourceFiles:inputFiles, sourceCodeString: sourceCode, isForServer: true)),
                typeStateDiagram: typeStateDiagram,
                callerCapabilityAnalysis: callerAnalysis,
                estimateGas: estimateGas)
            
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
        let fileName = "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/ide_examples/curr_examples/test.flint"
        let inputFiles = [URL(fileURLWithPath: fileName)]
        let sourceCode = try String(contentsOf: inputFiles[0])
        do {
            //print("this  is the first time running")
            let c = Compiler(
                sourceFiles: inputFiles,
                sourceCode: sourceCode,
                stdlibFiles: StandardLibrary.default.files,
                diagnostics: DiagnosticPool(shouldVerify: false,
                                            quiet: false,
                                            sourceContext: SourceContext(sourceFiles:inputFiles, sourceCodeString: sourceCode, isForServer: true)),
                typeStateDiagram : false,
                callerCapabilityAnalysis: false,
                estimateGas: true)
            
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
}

try main_d()
//main()
