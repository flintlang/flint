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
  var dumpAST: Bool
  var emitBytecode: Bool
  var diagnostics: DiagnosticPool

  var sourceContext: SourceContext {
    return SourceContext(sourceFiles: inputFiles)
  }

  func tokenizeFiles() throws -> [Token] {
    let stdlibTokens = try StandardLibrary.default.files.flatMap { try Lexer(sourceFile: $0, isFromStdlib: true).lex() }
    let userTokens = try inputFiles.flatMap { try Lexer(sourceFile: $0).lex() }

    return stdlibTokens + userTokens
  }
    
  func ide_compile() throws
  {
    let tokens = try tokenizeFiles()

    // Turn the tokens into an Abstract Syntax Tree (AST).
    let (parserAST, environment, parserDiagnostics) = Parser(tokens: tokens).parse()
    
    // add all parser diagnostics to the pool of diagnistics
    
    diagnostics.appendAll(parserDiagnostics)
    
//    if let failed = try diagnostics.checkpoint(parserDiagnostics) {
//        if failed {
//            exitWithFsailure()
//        }
//        exit(0)
//    }
    
    // at this point lets make it such that
    // only when we have a
    guard let ast = parserAST else {
        return
    }
    
    let astPasses: [ASTPass] = [
        SemanticAnalyzer(),
        TypeChecker(),
        Optimizer(),
        IRPreprocessor()
    ]
    
    //\\<->//\\<->//\\ Run all of the passes.
    let passRunnerOutcome = ASTPassRunner(ast: ast)
        .run(passes: astPasses, in: environment, sourceContext: sourceContext)
    
    // add semantic diagnostics
    diagnostics.appendAll(passRunnerOutcome.diagnostics)
//    if let failed = try diagnostics.checkpoint(passRunnerOutcome.diagnostics) {
//        if failed {
//            exitWithFailure()
//        }
//        exit(0)
//    }
    
    // all the diagnostics have been added
    return
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

    // Generate YUL IR code.
    let irCode = IRCodeGenerator(topLevelModule: passRunnerOutcome.element, environment: passRunnerOutcome.environment)
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
