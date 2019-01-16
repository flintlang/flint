public struct LSPDiagnosticRelatedInformation {
    
    private var Location : LSPRange
    
    private var Message : String
    
    init(location: LSPRange, message: String) {
        Location = location
        Message = message
    }
}
