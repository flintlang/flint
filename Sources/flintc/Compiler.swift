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

/// Runs the different stages of the compiler.
struct Compiler {
  var inputFiles: [URL]
  var stdlibFiles: [URL]
  var outputDirectory: URL
  var emitBytecode: Bool
  var shouldVerify: Bool

  func tokenizeFiles() -> [Token] {
    let stdlibTokens = StandardLibrary.default.files.flatMap { Tokenizer(sourceFile: $0, isFromStdlib: true).tokenize() }
    let userTokens = inputFiles.flatMap { Tokenizer(sourceFile: $0).tokenize() }

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
    let astPasses: [AnyASTPass] = [
      AnyASTPass(SemanticAnalyzer()),
      AnyASTPass(TypeChecker()),
      AnyASTPass(Optimizer()),
      AnyASTPass(IULIAPreprocessor())
    ]

    // Run all of the passes.
    let passRunnerOutcome = ASTPassRunner(ast: ast).run(passes: astPasses, in: environment, compilationContext: compilationContext)

    if !passRunnerOutcome.diagnostics.isEmpty, !shouldVerify {
      // Print the errors and warnings emitted during the passes.
      print(DiagnosticsFormatter(diagnostics: passRunnerOutcome.diagnostics, compilationContext: compilationContext).rendered())
    }

    if shouldVerify {
      // Used during development of the compiler: verify that the diagnostics emitted matches what we expected.
      if DiagnosticsVerifier().verify(producedDiagnostics: passRunnerOutcome.diagnostics, compilationContext: compilationContext) {
        exit(0)
      } else {
        exitWithFailure()
      }
    }

    guard !passRunnerOutcome.diagnostics.contains(where: { $0.isError }) else {
      // If there is at least one error, abort.
      exitWithFailure()
    }

    // Generate IULIA IR code.
    let irCode = IULIACodeGenerator(topLevelModule: passRunnerOutcome.element, environment: passRunnerOutcome.environment).generateCode()

    // Compile the IULIA IR code using solc.
    SolcCompiler(inputSource: irCode, outputDirectory: outputDirectory, emitBytecode: emitBytecode).compile()

    print("Produced binary in \(outputDirectory.path.bold).")
    return CompilationOutcome(irCode: irCode, astDump: ASTDumper(topLevelModule: ast).dump())
  }

  func exitWithFailure() -> Never {
    print("Failed to compile.")
    exit(1)
  }
}

struct CompilationContext {
  var sourceFiles: [URL]

  func sourceCode(in sourceFile: URL) -> String {
    return try! String(contentsOf: sourceFile)
  }
}

struct CompilationOutcome {
  var irCode: String
  var astDump: String
}
