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
import Utils

struct Analyser {
  let contractFile: String
  let sourceCode: String
  let estimateGas: Bool
  let typeStateDiagram: Bool
  let callerCapabilityAnalysis: Bool
  let isTestRun: Bool
  let functionAnalysis: Bool

  public func analyse() throws {
    let inputFiles = [URL(fileURLWithPath: contractFile)]
    let outputDirectory = Path.getFullUrl(path: "utils/gasEstimator")

    let diagnosticPool = DiagnosticPool(shouldVerify: false,
                                        quiet: false,
                                        sourceContext: SourceContext(
                                            sourceFiles: inputFiles,
                                            sourceCodeString: sourceCode,
                                            isForServer: true))

    let config = CompilerContractAnalyserConfiguration(sourceFiles: inputFiles,
                                                       sourceCode: sourceCode,
                                                       stdlibFiles: StandardLibrary.from(target: .evm).files,
                                                       outputDirectory: outputDirectory,
                                                       diagnostics: diagnosticPool)

    let (ast, environment) = try Compiler.getAST(config: config)

    if functionAnalysis {
      let fA = FunctionAnalysis()
      let graphs = fA.analyse(environment: environment)
      for g in graphs {
        print(g.produce_dot_graph())
      }

    }

    if estimateGas {
      let gasEstimator = GasEstimator(isTestRun: isTestRun)
      let newAst = gasEstimator.processAST(ast: ast)
      let parser = Parser(ast: newAst)
      let newEnv = parser.getEnv()
      try Compiler.genSolFile(config: config, ast: newAst, environment: newEnv)
      let gasEstimatorJson: String = gasEstimator.estimateGas(ast: newAst, environment: newEnv)
      print(gasEstimatorJson)
    }

    if callerCapabilityAnalysis {
      let callerAnalyser = CallAnalyser()
      let callerAnalyserJson: String = try callerAnalyser.analyse(ast: ast)
      print(callerAnalyserJson)
    }

    if typeStateDiagram {
      let gs: [Graph] = produceGraphsFromEnvironment(environment: environment)
      var dotFiles: [String] = []
      for g in gs {
        let dotFile = produceDotGraph(graph: g)
        dotFiles.append(dotFile)
      }
      for dot in dotFiles {
        print(dot)
      }
    }
  }
}
