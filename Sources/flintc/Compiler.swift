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
  var shouldVerify: Bool
  var quiet: Bool

  func tokenizeFiles() -> [Token] {
    let stdlibTokens = StandardLibrary.default.files.flatMap { Lexer(sourceFile: $0, isFromStdlib: true).lex() }
    let userTokens = inputFiles.flatMap { Lexer(sourceFile: $0).lex() }

    return stdlibTokens + userTokens
  }

  func compile() -> CompilationOutcome {
    let tokens = tokenizeFiles()

    // Turn the tokens into an Abstract Syntax Tree (AST).
    let (parserAST, environment, parserDiagnostics) = Parser(tokens: tokens).parse()

    // Create a compilation context.
    let compilationContext = CompilationContext(sourceFiles: inputFiles)

    guard let ast = parserAST, !parserDiagnostics.contains(where: { $0.isError }) else {
      // If there are any parser errors, abort execution.
      print(DiagnosticsFormatter(diagnostics: parserDiagnostics, compilationContext: compilationContext).rendered())
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
    let passRunnerOutcome = ASTPassRunner(ast: ast).run(passes: astPasses, in: environment, compilationContext: compilationContext)

    let diagnostics = passRunnerOutcome.diagnostics.filter {
      if case .warning = $0.severity {
        return !quiet
      }
      return true
    }

    if !diagnostics.isEmpty, !shouldVerify {
      // Print the errors and warnings emitted during the passes.
      print(DiagnosticsFormatter(diagnostics: diagnostics, compilationContext: compilationContext).rendered())
    }

    if shouldVerify {
      // Used during development of the compiler: verify that the diagnostics emitted matches what we expected.
      if DiagnosticsVerifier().verify(producedDiagnostics: diagnostics, compilationContext: compilationContext) {
        exit(0)
      } else {
        exitWithFailure()
      }
    }

    guard !diagnostics.contains(where: { $0.isError }) else {
      // If there is at least one error, abort.
      exitWithFailure()
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
