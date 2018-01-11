//
//  ASTVisitor.swift
//  SemanticAnalyzer
//
//  Created by Franklin Schrans on 1/11/18.
//

import Diagnostic

protocol DiagnosticsTracking: class {
  var diagnostics: [Diagnostic] { get set }
}

extension DiagnosticsTracking {
  func addDiagnostic(_ diagnostic: Diagnostic) {
    diagnostics.append(diagnostic)
  }
}
