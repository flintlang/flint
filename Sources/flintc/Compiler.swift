//
//  Compiler.swift
//  flintcPackageDescription
//
//  Created by Franklin Schrans on 12/19/17.
//

import Foundation
import AST
import Parser
import SemanticAnalyzer
import IRGen
import Diagnostic

struct Compiler {
  var inputFile: URL
  var outputDirectory: URL
  var emitBytecode: Bool
  
  func compile() -> CompilationOutcome {
    let sourceCode = try! String(contentsOf: inputFile, encoding: .utf8)
    
    let tokens = Tokenizer(sourceCode: sourceCode).tokenize()
    let (parserAST, context, parserDiagnostics) = Parser(tokens: tokens).parse()
    
    let compilationContext = CompilationContext(sourceCode: sourceCode, fileName: inputFile.lastPathComponent)

    guard let ast = parserAST, !parserDiagnostics.contains(where: { $0.isError }) else {
      print(DiagnosticsFormatter(diagnostics: parserDiagnostics, compilationContext: compilationContext).rendered())
      exitWithFailure()
    }

    let astPasses: [ASTPass.Type] = [
      SemanticAnalyzer.self,
      TypeChecker.self
    ]

    do {
      try ASTPassRunner(ast: ast).run(passes: astPasses, in: context, compilationContext: compilationContext)
    } catch {
      exitWithFailure()
    }

    let irCode = IULIACodeGenerator(topLevelModule: ast, context: context).generateCode()
    SolcCompiler(inputSource: irCode, outputDirectory: outputDirectory, emitBytecode: emitBytecode).compile()

    return CompilationOutcome(irCode: irCode, astDump: ASTDumper(topLevelModule: ast).dump())
  }

  func exitWithFailure() -> Never {
    print("Failed to compile \(inputFile.lastPathComponent).")
    exit(1)
  }
}

struct CompilationContext {
  var sourceCode: String
  var fileName: String
}

struct CompilationOutcome {
  var irCode: String
  var astDump: String
}
