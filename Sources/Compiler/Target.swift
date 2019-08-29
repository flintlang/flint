//
//  Target.swift
//  flintcPackageDescription
//
//  Created by Matthew Ross Rachar on 29/Jul/19.
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
import Utils
import MoveGen

public protocol Target {
  init(config: CompilerConfiguration, environment: Environment, sourceContext: SourceContext)
  func generate(ast: TopLevelModule) throws -> String
}

public class EVMTarget: Target {
  let config: CompilerConfiguration
  let environment: Environment
  let sourceContext: SourceContext

  required public init(config: CompilerConfiguration,
                       environment: Environment,
                       sourceContext: SourceContext) {
    self.config = config
    self.environment = environment
    self.sourceContext = sourceContext
  }

  public func generate(ast: TopLevelModule) throws -> String {
    // Run final IRPreprocessor pass
    let irPreprocessOutcome = ASTPassRunner(ast: ast).run(
        passes: (!config.skipVerifier ? [AssertPreprocessor()] : [])
            + [PreConditionPreprocessor(checkAllFunctions: config.skipVerifier),
          IRPreprocessor()],
        in: environment,
        sourceContext: sourceContext)
    if let failed = try config.diagnostics.checkpoint(irPreprocessOutcome.diagnostics) {
      if failed {
        print("ERROR\nFailed to compile for EVM Target.")
        exit(1)
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

    return irCode
  }
}

public class MoveTarget: Target {
  let config: CompilerConfiguration
  let environment: Environment
  let sourceContext: SourceContext

  required public init(config: CompilerConfiguration, environment: Environment, sourceContext: SourceContext) {
    self.config = config
    self.environment = environment
    self.sourceContext = sourceContext
  }

  public func generate(ast: TopLevelModule) throws -> String {
    // Run final IRPreprocessor pass
    let irPreprocessOutcome = ASTPassRunner(ast: ast).run(
        passes: (!config.skipVerifier ? [AssertPreprocessor()] : [])
            + [PreConditionPreprocessor(checkAllFunctions: config.skipVerifier),
               MoveScopeProcessor(),
               MoveMultipleBorrowPreventer(),
               MovePreprocessor()],
        in: environment,
        sourceContext: sourceContext)
    if let failed = try config.diagnostics.checkpoint(irPreprocessOutcome.diagnostics) {
      if failed {
        print("ERROR\nFailed to compile for Move Target.")
        exit(1)
      }
      exit(0)
    }
    let generator = MoveGenerator(ast: irPreprocessOutcome.element, environment: environment)
    return generator.generateCode()
  }
}
