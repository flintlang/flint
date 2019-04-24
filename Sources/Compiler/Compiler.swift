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
import ASTPreprocessor
import SemanticAnalyzer
import TypeChecker
import Optimizer
import IRGen
import Verifier

/// Runs the different stages of the compiler.
public struct Compiler {
  public static let defaultASTPasses: [ASTPass] = [
    ASTPreprocessor(),
    EnclosingTypeAssigner(),
    SemanticAnalyzer(),
    TypeChecker(),
    Optimizer(),
    TraitResolver(),
    FunctionCallCompleter(),
    CallGraphGenerator()]

  private static func exitWithFailure() -> Never {
    print("Failed to compile.")
    exit(1)
  }

  private static func tokenizeFiles(inputFiles: [URL], withStandardLibrary: Bool = true) throws -> [Token] {
    let stdlibTokens: [Token]
    if withStandardLibrary {
      stdlibTokens = try StandardLibrary.default.files.flatMap { try Lexer(sourceFile: $0, isFromStdlib: true).lex() }
    } else {
      stdlibTokens = []
    }

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
    let tokens = try tokenizeFiles(inputFiles: config.inputFiles, withStandardLibrary: config.loadStdlib)

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

    let sourceContext = SourceContext(sourceFiles: config.inputFiles)

    // Run all of the passes.
    let passRunnerOutcome = ASTPassRunner(ast: ast).run(passes: config.astPasses,
                                                        in: environment,
                                                        sourceContext: sourceContext)
    if let failed = try config.diagnostics.checkpoint(passRunnerOutcome.diagnostics) {
      if failed {
        exitWithFailure()
      }
      exit(0)
    }

    if config.dumpAST {
      print(ASTDumper(topLevelModule: passRunnerOutcome.element).dump())
      exit(0)
    }

    // Run verifier
    if !config.skipVerifier {
      let (verified, errors) = BoogieVerifier(dumpVerifierIR: config.dumpVerifierIR,
                                              printVerificationOutput: config.printVerificationOutput,
                                              skipHolisticCheck: config.skipHolisticCheck,
                                              printHolisticRunStats: config.printHolisticRunStats,
                                              boogieLocation: "boogie/Binaries/Boogie.exe",
                                              symbooglixLocation: "symbooglix/src/SymbooglixDriver/bin/Release/sbx.exe",
                                              maxHolisticTimeout: config.maxHolisticTimeout,
                                              monoLocation: "/usr/bin/mono",
                                              topLevelModule: passRunnerOutcome.element,
                                              environment: passRunnerOutcome.environment,
                                              sourceContext: sourceContext,
                                              normaliser: IdentifierNormaliser()).verify()

      if verified {
        print("Contract specification verified!")
      } else {
        print("Contract specification not verified")
        _ = try config.diagnostics.checkpoint(errors)
        exitWithFailure()
      }
    }

    if config.skipCodeGen {
      exit(0)
    }

    // Run final IRPreprocessor pass
    let irPreprocessOutcome = ASTPassRunner(ast: passRunnerOutcome.element).run(
      passes: [IRPreprocessor()],
      in: environment,
      sourceContext: sourceContext)
    if let failed = try config.diagnostics.checkpoint(irPreprocessOutcome.diagnostics) {
      if failed {
        exitWithFailure()
      }
      exit(0)
    }
    // Generate YUL IR code.
    let irCode = IRCodeGenerator(topLevelModule: irPreprocessOutcome.element,
                                 environment: irPreprocessOutcome.environment)
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
  public let dumpVerifierIR: Bool
  public let printVerificationOutput: Bool
  public let skipHolisticCheck: Bool
  public let skipVerifier: Bool
  public let printHolisticRunStats: Bool
  public let maxHolisticTimeout: Int
  public let skipCodeGen: Bool
  public let diagnostics: DiagnosticPool
  public let loadStdlib: Bool
  public let astPasses: [ASTPass]

  public init(inputFiles: [URL],
              stdlibFiles: [URL],
              outputDirectory: URL,
              dumpAST: Bool,
              emitBytecode: Bool,
              dumpVerifierIR: Bool,
              printVerificationOutput: Bool,
              skipHolisticCheck: Bool,
              printHolisticRunStats: Bool,
              maxHolisticTimeout: Int,
              skipVerifier: Bool,
              skipCodeGen: Bool,
              diagnostics: DiagnosticPool,
              loadStdlib: Bool = true,
              astPasses: [ASTPass] = Compiler.defaultASTPasses) {
    self.inputFiles = inputFiles
    self.stdlibFiles = stdlibFiles
    self.outputDirectory = outputDirectory
    self.dumpAST = dumpAST
    self.emitBytecode = emitBytecode
    self.dumpVerifierIR = dumpVerifierIR
    self.printVerificationOutput = printVerificationOutput
    self.skipHolisticCheck = skipHolisticCheck
    self.printHolisticRunStats = printHolisticRunStats
    self.maxHolisticTimeout = maxHolisticTimeout
    self.skipVerifier = skipVerifier
    self.skipCodeGen = skipCodeGen
    self.diagnostics = diagnostics
    self.astPasses = astPasses
    self.loadStdlib = loadStdlib
  }
}

public struct CompilationOutcome {
  public var irCode: String
  public var astDump: String
}
