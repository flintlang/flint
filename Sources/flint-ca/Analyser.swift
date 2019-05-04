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

struct Analyser {
    let contractFile : String
    let sourceCode : String
    let estimateGas : Bool
    let typeStateDiagram : Bool
    let callerCapabilityAnalysis : Bool
    

    public func analyse() throws
    {
        
        let inputFiles = [URL(fileURLWithPath: contractFile)]
        let outputDirectory = URL(fileURLWithPath: "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/gasEstimator")
        
        let c = Compiler(
                sourceFiles: inputFiles,
                sourceCode: sourceCode,
                stdlibFiles: StandardLibrary.default.files,
                outputDirectory: outputDirectory,
                diagnostics: DiagnosticPool(shouldVerify: false,
                                            quiet: false,
                                            sourceContext: SourceContext(sourceFiles: inputFiles))
                )
        
        let (ast, environment) = try c.getAST()
        
        
        if (estimateGas) {
            let gasEstimator = GasEstimator()
            let new_ast = gasEstimator.processAST(ast: ast)
            let p = Parser(ast: new_ast)
            let new_env = p.getEnv()
            try c.genSolFile(ast: new_ast, env: new_env)
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
