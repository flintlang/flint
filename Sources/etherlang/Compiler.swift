//
//  Compiler.swift
//  etherlangPackageDescription
//
//  Created by Franklin Schrans on 12/19/17.
//

import Foundation
import Parser
import SemanticAnalyzer
import IRGen
import Diagnostic

struct Compiler {
  var inputFile: URL
  var outputDirectory: URL
  
  func compile() -> CompilationOutcome {
    let sourceCode = try! String(contentsOf: inputFile, encoding: .utf8)
    
    let tokens = Tokenizer(sourceCode: sourceCode).tokenize()
    let (parserAST, context, parserDiagnostics) = Parser(tokens: tokens).parse()

    guard let ast = parserAST, !parserDiagnostics.contains(where: { $0.isError }) else {
      print(DiagnosticsFormatter(diagnostics: parserDiagnostics, sourceCode: sourceCode, fileName: inputFile.lastPathComponent).rendered())
      exitWithFailure()
    }

    let semanticAnalyzerDiagnostics = SemanticAnalyzer(ast: ast, context: context).analyze()
    print(DiagnosticsFormatter(diagnostics: parserDiagnostics + semanticAnalyzerDiagnostics, sourceCode: sourceCode, fileName: inputFile.lastPathComponent).rendered(), terminator: "")

    guard !semanticAnalyzerDiagnostics.contains(where: { $0.isError }) else {
      exitWithFailure()
    }

    let irCode = IRCodeGenerator(topLevelModule: ast, context: context).generateCode()
    SolcCompiler(inputSource: irCode, outputDirectory: outputDirectory).compile()

    return CompilationOutcome(irCode: irCode)
  }

  func exitWithFailure() -> Never {
    print("Failed to compile \(inputFile.lastPathComponent).")
    exit(1)
  }
}

struct CompilationOutcome {
  var irCode: String
}
