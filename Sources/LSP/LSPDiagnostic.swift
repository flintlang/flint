public struct LSPDiagnostic : Codable {
    
    private var Range : LSPRange
      
    private var Severity: Severity
    
    private var Code : String?
    
    private var Source : String?
    
    private var Message : String
    
    private var RelatedInformation : [LSPDiagnosticRelatedInformation]
    
    init(range: LSPRange, severity: Severity, code: String?, source: String?, message: String, relatedInfo: [LSPDiagnosticRelatedInformation]) {
        
        Range = range
        Severity = severity
        Code = code
        Source = source
        Message = message
        RelatedInformation = relatedInfo
    }
    
}
