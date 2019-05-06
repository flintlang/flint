import Foundation
import AST
import Diagnostic
import Lexer
import Parser
import SemanticAnalyzer
import TypeChecker
import Optimizer
import ContractAnalysis
import IRGen
import Compiler

struct Analyser {
    let contractFile : String
    let sourceCode : String
    let estimateGas : Bool
    let typeStateDiagram : Bool
    let callerCapabilityAnalysis : Bool
    let test_run : Bool
    

    public func analyse() throws
    {
        let inputFiles = [URL(fileURLWithPath: contractFile)]
        let outputDirectory = URL(fileURLWithPath: "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/gasEstimator")
        
        let config = CompilerContractAnalyserConfiguration(sourceFiles: inputFiles,
                                                           sourceCode: sourceCode,
                                                           stdlibFiles: StandardLibrary.default.files,
                                                           outputDirectory: outputDirectory,
                                                           diagnostics: DiagnosticPool(shouldVerify: false,
                                                                                       quiet: false,
                                                                                       sourceContext: SourceContext(sourceFiles: inputFiles, sourceCodeString: sourceCode, isForServer: true)))
       
        let (ast, environment) = try Compiler.getAST(config: config)
        
        if (estimateGas) {
            let gasEstimator = GasEstimator(test_run: test_run)
            let new_ast = gasEstimator.processAST(ast: ast)
            let p = Parser(ast: new_ast)
            let new_env = p.getEnv()
            try Compiler.genSolFile(config: config, ast: new_ast, env: new_env)
            let ge_json = gasEstimator.estimateGas(ast: new_ast, env: new_env)
            print(ge_json)
        }
        
        if (callerCapabilityAnalysis) {
            let callerAnalyser = CallAnalyser()
            let ca_json = try callerAnalyser.analyse(ast: ast)
            print(ca_json)
        }
        
        if (typeStateDiagram)
        {
            let gs : [Graph] = produce_graphs_from_ev(ev: environment)
            var dotFiles : [String] = []
            for g in gs {
                let dotFile = produce_dot_graph(graph: g)
                dotFiles.append(dotFile)
            }
            for dot in dotFiles {
                print(dot)
            }
        }
    }
    
    
}
