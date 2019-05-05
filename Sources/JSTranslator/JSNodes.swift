public enum JSNode : CustomStringConvertible {
    case FunctionCall(JSFunctionCall)
    case VariableAssignment(JSVariableAssignment)
    case Variable(JSVariable)
    case Literal(JSLiteral)
    
    public var description: String {
        switch (self) {
        case .Literal(let li):
            return li.description
        case .VariableAssignment(let vAssignment):
            return vAssignment.description
        case .Variable(let vari):
            return vari.description
        case .FunctionCall(let fCall):
            return fCall.description
        }
    }
}
