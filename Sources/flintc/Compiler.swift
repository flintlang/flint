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
import Optimizer
import IRGen

struct Compiler {
  var inputFile: URL
  var outputDirectory: URL
  var emitBytecode: Bool
  var shouldVerify: Bool
  
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
      TypeChecker.self,
      Optimizer.self
    ]

    let passRunnerOutcome = ASTPassRunner(ast: ast).run(passes: astPasses, in: context, compilationContext: compilationContext)

    if !passRunnerOutcome.diagnostics.isEmpty, !shouldVerify {
      print(DiagnosticsFormatter(diagnostics: passRunnerOutcome.diagnostics, compilationContext: compilationContext).rendered())
    }

    if shouldVerify {
      if DiagnosticsVerifier().verify(producedDiagnostics: passRunnerOutcome.diagnostics, compilationContext: compilationContext) {
        exit(0)
      } else {
        exitWithFailure()
      }
    }

    guard !passRunnerOutcome.diagnostics.contains(where: { $0.isError }) else {
      exitWithFailure()
    }

    let irCode = IULIACodeGenerator(topLevelModule: passRunnerOutcome.ast, context: context).generateCode()
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
