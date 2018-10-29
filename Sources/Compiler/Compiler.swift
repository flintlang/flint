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
public struct Compiler {
  public static let defaultASTPasses: [ASTPass] = [
    SemanticAnalyzer(),
    TypeChecker(),
    Optimizer(),
    TraitResolver(),
    FunctionCallCompleter(),
    IRPreprocessor()]

  private static func exitWithFailure() -> Never {
    print("Failed to compile.")
    exit(1)
  }

  private static func tokenizeFiles(inputFiles: [URL]) throws -> [Token] {
    let stdlibTokens = try StandardLibrary.default.files.flatMap { try Lexer(sourceFile: $0, isFromStdlib: true).lex() }
    let userTokens = try inputFiles.flatMap { try Lexer(sourceFile: $0).lex() }

    return stdlibTokens + userTokens
  }
}

// MARK: - Diagnosis
extension Compiler {
  public static func diagnose(config: DiagnoserConfiguration) throws -> [Diagnostic] {
    var diagnoseResult: [Diagnostic] = []
    let tokens = try tokenizeFiles(inputFiles: config.inputFiles)

    // Turn the tokens into an Abstract Syntax Tree (AST).
    let (parserAST, environment, parserDiagnostics) = Parser(tokens: tokens).parse()
    diagnoseResult += parserDiagnostics
    guard let ast = parserAST else {
      return diagnoseResult
    }

    // Run all of the passes.
    let passRunnerOutcome = ASTPassRunner(ast: ast).run(
      passes: config.astPasses,
      in: environment,
      sourceContext: SourceContext(sourceFiles: config.inputFiles))
    diagnoseResult += passRunnerOutcome.diagnostics

    return diagnoseResult
  }
}

// MARK: - Compilation
extension Compiler {
  public static func compile(config: CompilerConfiguration) throws -> CompilationOutcome {
    let tokens = try tokenizeFiles(inputFiles: config.inputFiles)

    // Turn the tokens into an Abstract Syntax Tree (AST).
    let (parserAST, environment, parserDiagnostics) = Parser(tokens: tokens).parse()

    if let failed = try config.diagnostics.checkpoint(parserDiagnostics) {
      if failed {
        exitWithFailure()
      }
      exit(0)
    }

    guard let ast = parserAST else {
      exitWithFailure()
    }

    if config.dumpAST {
      print(ASTDumper(topLevelModule: ast).dump())
      exit(0)
    }

    // Run all of the passes.
    let passRunnerOutcome = ASTPassRunner(ast: ast).run(
      passes: config.astPasses,
      in: environment,
      sourceContext: SourceContext(sourceFiles: config.inputFiles))
    if let failed = try config.diagnostics.checkpoint(passRunnerOutcome.diagnostics) {
      if failed {
        exitWithFailure()
      }
      exit(0)
    }

    // Generate YUL IR code.
    let irCode = IRCodeGenerator(topLevelModule: passRunnerOutcome.element, environment: passRunnerOutcome.environment)
      .generateCode()

    // Compile the YUL IR code using solc.
    try SolcCompiler(inputSource: irCode,
                     outputDirectory: config.outputDirectory,
                     emitBytecode: config.emitBytecode).compile()

    try config.diagnostics.display()

    print("Produced binary in \(config.outputDirectory.path.bold).")
    return CompilationOutcome(irCode: irCode, astDump: ASTDumper(topLevelModule: ast).dump())
  }
}

// MARK: - Configurations
public struct DiagnoserConfiguration {
  public let inputFiles: [URL]
  public let astPasses: [ASTPass]

  public init(inputFiles: [URL],
              astPasses: [ASTPass] = Compiler.defaultASTPasses) {
    self.inputFiles = inputFiles
    self.astPasses = astPasses
  }
}

public struct CompilerConfiguration {
  public let inputFiles: [URL]
  public let stdlibFiles: [URL]
  public let outputDirectory: URL
  public let dumpAST: Bool
  public let emitBytecode: Bool
  public let diagnostics: DiagnosticPool
  public let astPasses: [ASTPass]

  public init(inputFiles: [URL],
              stdlibFiles: [URL],
              outputDirectory: URL,
              dumpAST: Bool,
              emitBytecode: Bool,
              diagnostics: DiagnosticPool,
              astPasses: [ASTPass] = Compiler.defaultASTPasses) {
    self.inputFiles = inputFiles
    self.stdlibFiles = stdlibFiles
    self.outputDirectory = outputDirectory
    self.dumpAST = dumpAST
    self.emitBytecode = emitBytecode
    self.diagnostics = diagnostics
    self.astPasses = astPasses
  }
}

public struct CompilationOutcome {
  public var irCode: String
  public var astDump: String
}
