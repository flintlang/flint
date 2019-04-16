public class JSVariableAssignment : CustomStringConvertible {
    private let lhs : String
    private let isConstant: Bool
    private let rhs : JSNode
    
    public init(lhs: String, rhs: JSNode, isConstant: Bool) {
        self.lhs = lhs
        self.rhs = rhs
        self.isConstant = isConstant
    }
    
    public var description: String {
        let varModifier = isConstant ? "let" : "var"
        return varModifier + " " + lhs.description + " = " + rhs.description
    }
}
