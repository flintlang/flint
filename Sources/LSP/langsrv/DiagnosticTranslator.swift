//
//  DiagnosticTranslator.swift
//  AST
//
//  Created by Ethan on 27/10/2018.
//

import LanguageServerProtocol

import struct Diagnostic.Diagnostic
public typealias LSPDiagnostic = LanguageServerProtocol.Diagnostic

public func translateDiagnostic(diagnostic: Diagnostic) -> LSPDiagnostic {
    let line = diagnostic.sourceLocation!.line
    let col = diagnostic.sourceLocation!.column

    return LSPDiagnostic(
        range: Range(start: Position(line: line, character: col),
                     end: Position(line: line, character: col + 1)),
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
