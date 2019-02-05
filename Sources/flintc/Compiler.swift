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
import Verifier
import Optimizer
import IRGen

/// Runs the different stages of the compiler.
struct Compiler {
  var inputFiles: [URL]
  var stdlibFiles: [URL]
  var outputDirectory: URL
  var dumpAST: Bool
  var emitBytecode: Bool
  var dumpVerifierIR: Bool
  var skipVerifier: Bool
  var diagnostics: DiagnosticPool

  var sourceContext: SourceContext {
    return SourceContext(sourceFiles: inputFiles)
  }

  func tokenizeFiles() throws -> [Token] {
    let stdlibTokens = try StandardLibrary.default.files.flatMap { try Lexer(sourceFile: $0, isFromStdlib: true).lex() }
    let userTokens = try inputFiles.flatMap { try Lexer(sourceFile: $0).lex() }

    return stdlibTokens + userTokens
  }

  func compile() throws -> CompilationOutcome {
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

    if dumpAST {
      print(ASTDumper(topLevelModule: ast).dump())
      exit(0)
    }

    // The AST passes to run sequentially.
    let astPasses: [ASTPass] = [
      SemanticAnalyzer(),
      TypeChecker()
    ]

    // AST Pass 1
    let semanticsPassRunnerOutcome = ASTPassRunner(ast: ast)
      .run(passes: astPasses, in: environment, sourceContext: sourceContext)
    if let failed = try diagnostics.checkpoint(semanticsPassRunnerOutcome.diagnostics) {
      if failed {
        exitWithFailure()
      }
      exit(0)
    }

    // AST Verification
    if !skipVerifier {
      let (verified, errors) = Verifier(dumpVerifierIR: dumpVerifierIR,
                             boogieLocation: "boogie/Binaries/Boogie.exe",
                             monoLocation: "/usr/bin/mono",
                             topLevelModule: semanticsPassRunnerOutcome.element,
                             environment: semanticsPassRunnerOutcome.environment).verify()

      if verified {
        print("Verified!")
      } else {
        print("Not verified")
        print(errors.reduce("", {x, y in x + "\n\(y.0), \(y.1)"}))
        exitWithFailure()
      }
    }

    // AST Pass 2
    let irGenerationPasses: [ASTPass] = [
      Optimizer(),
      IRPreprocessor()
    ]

    let irPassRunnerOutcome = ASTPassRunner(ast: semanticsPassRunnerOutcome.element)
      .run(passes: irGenerationPasses, in: semanticsPassRunnerOutcome.environment, sourceContext: sourceContext)
    if let failed = try diagnostics.checkpoint(irPassRunnerOutcome.diagnostics) {
      if failed {
        exitWithFailure()
      }
      exit(0)
    }

    // Generate YUL IR code.
    let irCode = IRCodeGenerator(topLevelModule: irPassRunnerOutcome.element,
                                 environment: irPassRunnerOutcome.environment)
      .generateCode()

    // Compile the YUL IR code using solc.
    try SolcCompiler(inputSource: irCode, outputDirectory: outputDirectory, emitBytecode: emitBytecode).compile()

    try diagnostics.display()

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
