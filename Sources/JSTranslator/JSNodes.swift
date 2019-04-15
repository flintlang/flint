public enum JSNode {
    case FunctionCall(JSFunctionCall)
    case VariableAssignment(JSVariableAssignment)
    case Variable(JSVariable)
}
