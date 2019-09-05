import Foundation
import AST
import Diagnostic
import Lexer
import Parser
import SemanticAnalyzer
import TypeChecker
import Optimizer
import IRGen
import JSTranslator
import Compiler
import Coverage
import Utils

struct TestRunner {
  let testFile: URL
  let sourceCode: String
  var diagnostics: DiagnosticPool
  let test_run: Bool
  let coverage: Bool

  func tokenizeTestFile() throws -> [Token] {
    let testTokens = try Lexer(sourceFile: testFile, isFromStdlib: false, isForServer: true, sourceCode: sourceCode
    ).lex()
    return testTokens
  }

  func run_tests() throws {
    let tokens = try tokenizeTestFile()

    // compiling the test contract
    let (parserAST, _, parserDiagnostics) = Parser(tokens: tokens).parse()

    // this should fail if the test contract is synctacially incorrect
    if let failed = try diagnostics.checkpoint(parserDiagnostics) {
      if failed {
        exitWithFailure()
      }
      exit(0)
    }

    // create a JSTestSuite
    let jsTestSuite = JSTranslator(ast: parserAST!, coverage: coverage)

    // extract the flint contract which is being tested
    let pathToFlintContract = jsTestSuite.getFilePathToFlintContract()

    let inputFiles = [URL(fileURLWithPath: pathToFlintContract)]
    let outputDirectory = Path.getFullUrl(path: "utils/testRunner")
    let contract_sourceCode = try String(contentsOf: inputFiles[0])

    let config = CompilerTestFrameworkConfiguration(sourceFiles: inputFiles,
                                                    sourceCode: contract_sourceCode,
                                                    stdlibFiles: StandardLibrary.from(target: .evm).files,
                                                    outputDirectory: outputDirectory,
                                                    diagnostics: DiagnosticPool(shouldVerify: false,
                                                                                quiet: false,
                                                                                sourceContext: SourceContext(
                                                                                    sourceFiles: inputFiles)))

    // Compile the contract
    do {
      var (ast, _) = try Compiler.getAST(config: config)

      if coverage {
        let cv = CoverageProvider()
        ast = cv.instrument(ast: ast)
      }

      try Compiler.compileForTest(config: config, inAst: ast)

    } catch let err {
      print(err)
      print("Failed to compile contract that is being tested")
    }

    // create java script file and then run it
    jsTestSuite.convertAST()
    let jsTestFile: String = jsTestSuite.genFile()

    if test_run {
      print(jsTestFile)
    } else {
      try runNode(jsTestFile: jsTestFile)
      if coverage {
        let contractName = jsTestSuite.getContractName()
        try genCovReport(contract_name: contractName, contract_file_path: pathToFlintContract)
      }
    }
  }

  func genCovReport(contract_name: String, contract_file_path: String) throws {
    Process.run(executableURL: Configuration.nodeLocation,
                arguments: ["--no-warnings", "gen_cov_report.js", contract_name, contract_file_path],
                currentDirectoryURL: Path.getFullUrl(path: "utils/coverage"))
  }

  func runNode(jsTestFile: String) throws {
    let outputfile = Path.getFullUrl(path: "utils/testRunner/test.js")
    try jsTestFile.write(to: outputfile, atomically: true, encoding: String.Encoding.utf8)
    Process.run(executableURL: Configuration.nodeLocation,
                arguments: ["--no-warnings", "test.js"],
                currentDirectoryURL: Path.getFullUrl(path: "utils/testRunner"))
  }

  func exitWithFailure() -> Never {
    print("Failed to compile.")
    exit(EXIT_FAILURE)
  }
}
