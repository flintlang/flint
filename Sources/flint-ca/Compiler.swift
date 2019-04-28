//
//  Compiler.swift
//  flintcPackageDescription
//
//  Created by Franklin Schrans on 12/19/17.
//

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

/// Runs the different stages of the compiler.
struct Compiler {
  var sourceFiles: [URL]
  var sourceCode: String
  var stdlibFiles: [URL]
  var diagnostics: DiagnosticPool
  var typeStateDiagram : Bool
  var callerCapabilityAnalysis: Bool

  var sourceContext: SourceContext {
    return SourceContext(sourceFiles: sourceFiles, sourceCodeString: sourceCode, isForServer: true)
  }

  func tokenizeFiles() throws -> [Token] {
    let stdlibTokens = try StandardLibrary.default.files.flatMap { try Lexer(sourceFile: $0, isFromStdlib: true).lex() }
    let userTokens = try Lexer(sourceFile: sourceFiles[0], isFromStdlib: false, isForServer: true, sourceCode: sourceCode).lex()
    return stdlibTokens + userTokens
  }
    
  func ide_compile() throws
  {
    let tokens = try tokenizeFiles()

    // Turn the tokens into an Abstract Syntax Tree (AST).
    let (parserAST, environment, parserDiagnostics) = Parser(tokens: tokens).parse()
    
    if let failed = try diagnostics.checkpoint(parserDiagnostics) {
        if failed {
            exitWithFailure()
        }
        exit(0)
    }
    
    guard let ast = parserAST else {
        exitWithFailure()
    }
    
    let astPasses: [ASTPass] = [
        SemanticAnalyzer(),
        TypeChecker(),
        Optimizer(),
        IRPreprocessor()
    ]
    
    // Run all of the passes.
    let passRunnerOutcome = ASTPassRunner(ast: ast)
        .run(passes: astPasses, in: environment, sourceContext: sourceContext)
    if let failed = try diagnostics.checkpoint(passRunnerOutcome.diagnostics) {
        if failed {
            exitWithFailure()
        }
        exit(0)
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
    
    return
  }
    
  func exitWithFailure() -> Never {
        print("ERROR")
        exit(0)
  }
}

