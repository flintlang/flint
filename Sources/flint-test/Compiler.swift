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
import LSP
import IRGen
import JSTranslator

/// Runs the different stages of the compiler.
struct Compiler {
  var sourceFiles: [URL]
  var sourceCode: String
  var stdlibFiles: [URL]
  var outputDirectory: URL
  var diagnostics: DiagnosticPool


  var sourceContext: SourceContext {
    return SourceContext(sourceFiles: sourceFiles, sourceCodeString: sourceCode, isForServer: true)
  }

  func tokenizeFiles() throws -> [Token] {
    let stdlibTokens = try StandardLibrary.default.files.flatMap { try Lexer(sourceFile: $0, isFromStdlib: true).lex() }
    let userTokens = try Lexer(sourceFile: sourceFiles[0], isFromStdlib: false, isForServer: true, sourceCode: sourceCode).lex()
    return stdlibTokens + userTokens
  }
    
    func createConstructor(constructor : SpecialDeclaration) -> FunctionDeclaration? {
        
        if (!(constructor.signature.specialToken.kind == .init)) {
            return nil
        }
        
        if (constructor.body.count == 0) {
            return nil
        }

        var sig = constructor.signature
        sig.modifiers.append(Token(kind: Token.Kind.mutating, sourceLocation : sig.sourceLocation))
        let tok : Token = Token(kind: Token.Kind.func, sourceLocation: sig.sourceLocation)
        let newFunctionSig = FunctionSignatureDeclaration(funcToken: tok, attributes: sig.attributes, modifiers: sig.modifiers, identifier: Identifier(name: "testFrameworkConstructor", sourceLocation: sig.sourceLocation), parameters: sig.parameters, closeBracketToken: sig.closeBracketToken, resultType: nil)
        let newFunc = FunctionDeclaration(signature: newFunctionSig, body: constructor.body, closeBraceToken: constructor.closeBraceToken)
        
        return newFunc
    }
    
    func insertConstructorFunc(ast : TopLevelModule) -> TopLevelModule {
      let decWithoutStdlib = ast.declarations[2...]
        
      var newDecs : [TopLevelDeclaration] = []
      newDecs.append(ast.declarations[0])
      newDecs.append(ast.declarations[1])

      for m in decWithoutStdlib {
          switch (m) {
          case .contractDeclaration(let cdec):
                newDecs.append(m)
          case .contractBehaviorDeclaration(var cbdec):
            var mems : [ContractBehaviorMember] = []
            for cm in cbdec.members {
                switch (cm) {
                case .specialDeclaration(let spdec):
                    if let constructorFunc = createConstructor(constructor: spdec) {
                        let cBeh : ContractBehaviorMember = .functionDeclaration(constructorFunc)
                        mems.append(cBeh)
                        mems.append(.specialDeclaration(spdec))
                    } else {
                        mems.append(cm)
                    }
                default:
                    mems.append(cm)
                }
            }
            cbdec.members = mems
            newDecs.append(.contractBehaviorDeclaration(cbdec))
          default:
                newDecs.append(m)
          }
      }
        
      return TopLevelModule(declarations: newDecs)
    }
    
  func compile() throws {
        let tokens = try tokenizeFiles()
        
        // Turn the tokens into an Abstract Syntax Tree (AST).
        let (parserAST, environment, parserDiagnostics) = Parser(tokens: tokens).parse()
    
        if let failed = try diagnostics.checkpoint(parserDiagnostics) {
            if failed {
                exitWithFailure()
            }
            exit(0)
        }
        
        guard var ast = parserAST else {
            exitWithFailure()
        }

        ast = insertConstructorFunc(ast: parserAST!)
    
        // The AST passes to run sequentially.
        let astPasses: [ASTPass] = [
            SemanticAnalyzer(),
            TypeChecker(),
            Optimizer(),
            IRPreprocessor()
        ]
        
        // Run all of the passes. (Semantic checks)
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
        try SolcCompiler(inputSource: irCode, outputDirectory: outputDirectory, emitBytecode: false).compile()
    
        // these are warnings from the solc compiler
        try diagnostics.display()

        let fileName = "main.sol"
        let irFileURL: URL
        irFileURL = outputDirectory.appendingPathComponent(fileName)
        do {
            try irCode.write(to: irFileURL, atomically: true, encoding: .utf8)
        } catch {
            exitWithUnableToWriteIRFile(irFileURL: irFileURL)
        }

    
    }
    
    func exitWithFailure() -> Never {
        print("Failed to compile.")
        exit(1)
    }
    
}

func exitWithSolcNotInstalledDiagnostic() -> Never {
    let diagnostic = Diagnostic(
        severity: .error,
        sourceLocation: nil,
        message: "Missing dependency: solc",
        notes: [
            Diagnostic(
                severity: .note,
                sourceLocation: nil,
                message: "Refer to http://solidity.readthedocs.io/en/develop/installing-solidity.html " +
                "for installation instructions.")
        ]
    )
    // swiftlint:disable force_try
    print(try! DiagnosticsFormatter(diagnostics: [diagnostic], sourceContext: nil).rendered())
    // swiftlint:enable force_try
    exit(1)
}

func exitWithUnableToWriteIRFile(irFileURL: URL) {
    let diagnostic = Diagnostic(severity: .error,
                                sourceLocation: nil,
                                message: "Could not write IR file: '\(irFileURL.path)'.")
    // swiftlint:disable force_try
    print(try! DiagnosticsFormatter(diagnostics: [diagnostic], sourceContext: nil).rendered())
    // swiftlint:enable force_try
    exit(1)
}



