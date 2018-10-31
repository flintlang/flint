//
//  DiagnosticTranslator.swift
//  AST
//
//  Created by Ethan on 27/10/2018.
//

import LanguageServerProtocol

import struct Diagnostic.Diagnostic
public typealias LSPDiagnostic = LanguageServerProtocol.Diagnostic

public func translateDiagnostic(diagnostic: Diagnostic) -> LSPDiagnostic? {
  guard let sourceLocation = diagnostic.sourceLocation else {
    return nil
  }

    let line = sourceLocation.line - 1
    let col = sourceLocation.column

    return LSPDiagnostic(
        range: Range(start: Position(line: line, character: col - 1),
                     end: Position(line: line, character: col + sourceLocation.length - 1)),
        message: diagnostic.message,
        severity: translateSeverity(severity: diagnostic.severity))
}

private func translateSeverity(severity: Diagnostic.Severity)
    -> LanguageServerProtocol.DiagnosticSeverity {
        switch severity {
        case .error:
            return LanguageServerProtocol.DiagnosticSeverity.error
        case .note:
            return LanguageServerProtocol.DiagnosticSeverity.information
        case .warning:
            return LanguageServerProtocol.DiagnosticSeverity.warning
        }
}
