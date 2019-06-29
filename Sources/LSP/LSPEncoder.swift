import Diagnostic
import Foundation

private let SourceMessage : String = "LSP LANGUAGE SERVER"

private func convertFlintDiagToLspDiag(_ diagnostic: Diagnostic) -> LSPDiagnostic {
    let lspSev = makeLSPSeverity(diagnostic)
    let message = makeLSPMessage(diagnostic)
    let lspCode = makeLSPCode(diagnostic)
    let relatedInfo = makeLSPRelatedInfo(diagnostic)
    let range = makeLSPRange(diagnostic)
    
    return LSPDiagnostic(range: range,
                         severity: lspSev,
                         code: lspCode,
                         source: SourceMessage,
                         message: message,
                         relatedInfo: relatedInfo)
    
}

public func convertFlintDiagToLspDiagJson(_ diagnostics : [Diagnostic]) throws -> String {
    let lspDiags : [LSPDiagnostic] = convertFlintDiagnosticsToLspDiagnostics(diagnostics)
    
    let encoder = JSONEncoder()
    let json = try encoder.encode(lspDiags)
    
    return String(data: json, encoding: .utf8)!
}

private func convertFlintDiagnosticsToLspDiagnostics(_ diagnostics: [Diagnostic]) -> [LSPDiagnostic] {
    
    var lspDiagnostics: [LSPDiagnostic] = []
    
    for d in diagnostics
    {
        lspDiagnostics.append(convertFlintDiagToLspDiag(d))
    }
    
    return lspDiagnostics
}

// check this function to ensure that the different ranges are safe
private func makeLSPRange(_ diagnostic: Diagnostic) -> LSPRange {
    let diag = diagnostic.sourceLocation!
    let startLine = diag.line
    let startChar = diag.column
    let endLine = diag.line
    let length = diag.length
    let endChar = length + diag.column
    let range : LSPRange = LSPRange(startLineNum: startLine - 1,
                                    startColumnNum: startChar,
                                    endLineNum: endLine - 1,
                                    endColumnNum: endChar)
    return range
}

private func makeLSPCode(_ diagnostic: Diagnostic) -> String? {
    return ""
}

private func makeLSPRelatedInfo(_ diagnostic: Diagnostic) -> [LSPDiagnosticRelatedInformation] {
    return []
}

private func makeLSPMessage(_ diagnostic: Diagnostic) -> String
{
    return diagnostic.message
}

private func makeLSPSeverity(_ diagnostic: Diagnostic) -> Severity {
    let lspSev : Severity;
    
    switch diagnostic.severity {
    case .error:
        lspSev = Severity.Error
    case .warning:
        lspSev = Severity.Warning
    default:
        lspSev = Severity.Error
    }
    
    return lspSev
}
