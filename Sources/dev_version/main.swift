import Foundation
import Commander
import AST
import LSP
import Diagnostic

/// The main function for the compiler.
func main() {
    
    command (
        Argument<String> ("source code", description: "source code to verify"),
        Argument<String> ("file name", description: "file name")
    )
    { sourceCode, fileName in
        let inputFiles = [URL(fileURLWithPath: fileName)]
        do {
            //print("this  is the first time running")
            let c = Compiler(
                sourceFiles: inputFiles,
                sourceCode: sourceCode,
                stdlibFiles: StandardLibrary.default.files,
                diagnostics: DiagnosticPool(shouldVerify: false,
                                            quiet: false,
                        sourceContext: SourceContext(sourceFiles:inputFiles, sourceCodeString: sourceCode, isForServer: true)))
            
            try c.ide_compile()
            let diag = c.diagnostics
            let json = try convertFlintDiagToLspDiagJson(diag.getDiagnostics())
            print(json)
            
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

main()
