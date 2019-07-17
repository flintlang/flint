import Foundation
import AST
import Diagnostic
import Lexer
import Parser
import SemanticAnalyzer
import TypeChecker
import Optimizer
import LSP
import IRGen
import JSTranslator
import Compiler
import Coverage
import Utils

struct TestRunner {
    let testFile : URL
    let sourceCode : String
    var diagnostics: DiagnosticPool
    let test_run : Bool
    let coverage : Bool
    
    func tokenizeTestFile() throws -> [Token] {
        let testTokens = try Lexer(sourceFile: testFile, isFromStdlib: false, isForServer: true, sourceCode: sourceCode).lex()
        return testTokens
    }
    
    func run_tests() throws
    {
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
        //let outputDirectory = URL(fileURLWithPath: "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/testRunner")
        let outputDirectory = Path.getFullUrl(path: "utils/testRunner")
        let contract_sourceCode = try String(contentsOf: inputFiles[0])
        
        let config = CompilerTestFrameworkConfiguration(sourceFiles: inputFiles,
                                                        sourceCode: contract_sourceCode,
                                                        stdlibFiles: StandardLibrary.default.files,
                                                        outputDirectory: outputDirectory,
                                                        diagnostics: DiagnosticPool(shouldVerify: false,
                                                                                    quiet: false, sourceContext: SourceContext(sourceFiles: inputFiles)))
        
        // Compile the contract
        do {
            var (ast, _) = try Compiler.getAST(config: config)
            
            if (coverage) {
                let cv = CoverageProvider()
                ast = cv.instrument(ast: ast)
            }
      
            try Compiler.compile_for_test(config: config, in_ast: ast)
            
        } catch let err {
            print(err)
            print("Failed to compile contract that is being tested")
        }
        
        // create java script file and then run it
        jsTestSuite.convertAST()
        let jsTestFile : String = jsTestSuite.genFile()
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
        let p = Process()
        p.launchPath = "/usr/bin/env"
        // p.currentDirectoryPath = "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/coverage"
        p.currentDirectoryPath = Path.getFullUrl(path: "utils/coverage").absoluteString
        p.arguments = ["node", "--no-warnings", "gen_cov_report.js", contract_name, contract_file_path]
        p.launch()
        p.waitUntilExit()
    }
    
    func runNode(jsTestFile : String) throws {
        let fileManager = FileManager.init()
        let outputfile = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: false).appendingPathComponent("utils").appendingPathComponent("testRunner").appendingPathComponent("test.js")
        try jsTestFile.write(to: outputfile, atomically: true, encoding: String.Encoding.utf8)
        
        let p = Process()
        p.launchPath = "/usr/bin/env"
        p.currentDirectoryPath = Path.getFullUrl(path: "utils/testRunner").absoluteString  /* %"/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/testRunner" */
        p.arguments = ["node", "--no-warnings", "test.js"]
        p.launch()
        p.waitUntilExit()
    }
    
    func exitWithFailure() -> Never {
        print("Failed to compile.")
        exit(1)
    }
}
