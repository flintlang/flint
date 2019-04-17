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


struct TestRunner {
    let testFile : URL
    let sourceCode : String
    var diagnostics: DiagnosticPool
    
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
        let jsTestSuite = JSTestSuite(ast: parserAST!)
        
        // extract the flint contract which is being tested
        let pathToFlintContract = jsTestSuite.getFilePathToFlintContract()
        
        let inputFiles = [URL(fileURLWithPath: pathToFlintContract)]
        let outputDirectory = URL(fileURLWithPath: "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/testRunner")
        
        // compile the contract that is being tested
        do {
           let sourceCode = try String(contentsOf: inputFiles[0])
           try Compiler(
                sourceFiles: inputFiles,
                sourceCode: sourceCode,
                stdlibFiles: StandardLibrary.default.files,
                outputDirectory: outputDirectory,
                diagnostics: DiagnosticPool(shouldVerify: false,
                                            quiet: false,
                                            sourceContext: SourceContext(sourceFiles: inputFiles))
                ).compile()
        } catch {
            print("Failed to compile contract that is being tested")
        }
        
        // create java script file and then run it
        jsTestSuite.convertAST()
        let jsTestFile : String = jsTestSuite.genFile()
        try runNode(jsTestFile: jsTestFile)
    }
    
    func runNode(jsTestFile : String) throws {
        let fileManager = FileManager.init()
        let outputfile = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: false).appendingPathComponent("utils").appendingPathComponent("testRunner").appendingPathComponent("test.js")
        try jsTestFile.write(to: outputfile, atomically: true, encoding: String.Encoding.utf8)
        
        let p = Process()
        p.launchPath = "/usr/bin/env"
        p.currentDirectoryPath = "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/testRunner"
        p.arguments = ["node", "test.js"]
        p.launch()
        p.waitUntilExit()
    }
    
    func exitWithFailure() -> Never {
        print("Failed to compile.")
        exit(1)
    }
}
