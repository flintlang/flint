import Diagnostic

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

public func convertFlintDiagToLspDiagJson(_ diagnostics : [Diagnostic]) -> String {
   return ""
}

private func convertFlintDiagnosticsToLspDiagnostics(_ diagnostics: [Diagnostic]) -> [LSPDiagnostic] {
    
    var lspDiagnostics: [LSPDiagnostic] = []
    
    for d in diagnostics
    {
        lspDiagnostics.append(convertFlintDiagToLspDiag(d))
    }
    
    return lspDiagnostics
}

private func makeLSPRange(_ diagnostic: Diagnostic) -> LSPRange {
    let x : LSPRange = LSPRange(startLineNum: 1, startColumNum: 10, endLineNum: 1, endColumnNum: 15)
    return x
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
