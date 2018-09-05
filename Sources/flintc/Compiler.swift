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
import IRGen

/// Runs the different stages of the compiler.
struct Compiler {
  var inputFiles: [URL]
  var stdlibFiles: [URL]
  var outputDirectory: URL
  var emitBytecode: Bool
  var diagnostics: DiagnosticPool
  var sourceContext: SourceContext {
    return SourceContext(sourceFiles: inputFiles)
  }

  func tokenizeFiles() -> [Token] {
    let stdlibTokens = StandardLibrary.default.files.flatMap { Lexer(sourceFile: $0, isFromStdlib: true).lex() }
    let userTokens = inputFiles.flatMap { Lexer(sourceFile: $0).lex() }

    return stdlibTokens + userTokens
  }

  func compile() -> CompilationOutcome {
    let tokens = tokenizeFiles()

    // Turn the tokens into an Abstract Syntax Tree (AST).
    let (parserAST, environment, parserDiagnostics) = Parser(tokens: tokens).parse()

    if let failed = diagnostics.checkpoint(parserDiagnostics) {
      if failed {
        exitWithFailure()
      }
      exit(0)
    }

    guard let ast = parserAST else {
      exitWithFailure()
    }
    // The AST passes to run sequentially.
    let astPasses: [ASTPass] = [
      SemanticAnalyzer(),
      TypeChecker(),
      Optimizer(),
      IRPreprocessor()
    ]

    // Run all of the passes.
    let passRunnerOutcome = ASTPassRunner(ast: ast).run(passes: astPasses, in: environment, sourceContext: sourceContext)
    if let failed = diagnostics.checkpoint(passRunnerOutcome.diagnostics) {
      if failed {
        exitWithFailure()
      }
      exit(0)
    }


    // Generate YUL IR code.
    let irCode = IRCodeGenerator(topLevelModule: passRunnerOutcome.element, environment: passRunnerOutcome.environment).generateCode()

    // Compile the YUL IR code using solc.
    SolcCompiler(inputSource: irCode, outputDirectory: outputDirectory, emitBytecode: emitBytecode).compile()

    print("Produced binary in \(outputDirectory.path.bold).")
    return CompilationOutcome(irCode: irCode, astDump: ASTDumper(topLevelModule: ast).dump())
  }

  func exitWithFailure() -> Never {
    print("Failed to compile.")
    exit(1)
  }
}

struct CompilationOutcome {
  var irCode: String
  var astDump: String
}
