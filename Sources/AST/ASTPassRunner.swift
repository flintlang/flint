//
//  ASTPassRunner.swift
//  AST
//
//  Created by Franklin Schrans on 1/11/18.
//
import Diagnostic

/// Visits an AST using multiple AST passes.
public struct ASTPassRunner {
  var ast: TopLevelModule

  public init(ast: TopLevelModule){
    self.ast = ast
  }

  public func run(passes: [ASTPass], in environment: Environment, compilationContext: CompilationContext) -> ASTPassRunResult {
    var environment = environment
    var ast = self.ast
    var diagnostics = [Diagnostic]()

    for pass in passes {
      // Runs each pass, passing along the enviroment built at the previous pass.

      let passContext = ASTPassContext().withUpdates { $0.environment = environment }
      let result = ASTVisitor(pass: pass).visit(ast, passContext: passContext)
      environment = result.passContext.environment!
      ast = result.element

      guard !result.diagnostics.isEmpty else { continue }
      diagnostics.append(contentsOf: result.diagnostics)
    }

    return ASTPassRunResult(element: ast, diagnostics: diagnostics, environment: environment)
  }
}

/// The result after running a sequence of AST passes.
public struct ASTPassRunResult {
  public var element: TopLevelModule
  public var diagnostics: [Diagnostic]
  public var environment: Environment
}
