public struct LSPDiagnostic {
    
    private var range : LSPRange
    
    private enum Severity: Int
    {
        case Error = 1
        case Warning = 2
        case Information = 3
        case Hint = 4
    }
    
    private var code : String?
    
    private var source : String?
    
    private var message : String
    
    private var RelatedInformation : [LSPDiagnosticRelatedInformation]
    
}
