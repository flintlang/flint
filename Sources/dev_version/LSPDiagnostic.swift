public struct LSPDiagnostic {
    
    private var Range : LSPRange
    
    private enum SeverityTypes: Int
    {
        case Error = 1
        case Warning = 2
        case Information = 3
        case Hint = 4
    }
    
    private var Severity: SeverityTypes
    
    private var Code : String?
    
    private var Source : String?
    
    private var Message : String
    
    private var RelatedInformation : [LSPDiagnosticRelatedInformation]
    
    init(range: LSPRange, severity: SeverityTypes, code: String?, source: String?, message: String, relatedInfo: [LSPDiagnosticRelatedInformation]) {
        
        Range = range
        Severity = severity
        Code = code
        Source = source
        Message = message
        Related = relatedInfo
    }
    
}
