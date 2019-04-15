public class JSVariableAssignment {
    private let assignee : String
    private let expression : JSNode
    
    public init(assignee: String, expression: JSNode) {
        self.assignee = assignee
        self.expression = expression
    }
    
}
