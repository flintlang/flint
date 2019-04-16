public class JSVariableAssignment {
    private let lhs : String
    private let isConstant: Bool
    private let rhs : JSNode
    
    public init(lhs: String, rhs: JSNode, isConstant: Bool) {
        self.lhs = lhs
        self.rhs = rhs
        self.isConstant = isConstant
    }
    
}
