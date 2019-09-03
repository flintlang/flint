import Foundation
import Commander
import AST
import LSP
import Diagnostic
import Compiler
import Utils

/// The main function for the compiler.
func main() {
  command(
      Argument<String>("source code", description: "source code to verify"),
      Argument<String>("file name", description: "file name")
  ) { sourceCode, fileName in
    let inputFiles = [URL(fileURLWithPath: fileName)]
    do {

      let config = CompilerLSPConfiguration(sourceFiles: inputFiles,
                                            sourceCode: sourceCode,
                                            stdlibFiles: StandardLibrary.from(target: .evm).files,
                                            diagnostics: DiagnosticPool(shouldVerify: false,
                                                                        quiet: false,
                                                                        sourceContext: SourceContext(
                                                                            sourceFiles: inputFiles,
                                                                            sourceCodeString: sourceCode,
                                                                            isForServer: true)))
      let diags = try Compiler.ide_compile(config: config)
      let lsp_json = try convertFlintDiagToLspDiagJson(diags)
      print(lsp_json)

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
  let fileName = Path.getFullUrl(path: "ide_examples/curr_examples/test.flint").path
  let inputFiles = [URL(fileURLWithPath: fileName)]
  let sourceCode = try String(contentsOf: inputFiles[0])
  do {

    let config = CompilerLSPConfiguration(sourceFiles: inputFiles,
                                          sourceCode: sourceCode,
                                          stdlibFiles: StandardLibrary.from(target: .evm).files,
                                          diagnostics: DiagnosticPool(shouldVerify: false,
                                                                      quiet: false,
                                                                      sourceContext: SourceContext(
                                                                          sourceFiles: inputFiles,
                                                                          sourceCodeString: sourceCode,
                                                                          isForServer: true)))
    let diags = try Compiler.ide_compile(config: config)
    let lsp_json = try convertFlintDiagToLspDiagJson(diags)
    print(lsp_json)

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

main()
