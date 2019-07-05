import Foundation

public enum JSNode : CustomStringConvertible {
    case FunctionCall(JSFunctionCall)
    case VariableAssignment(JSVariableAssignment)
    case Variable(JSVariable)
    case Literal(JSLiteral)
    
    public func getType() -> String {
        switch (self) {
        case .FunctionCall(let fCall):
            return fCall.getType()
        case .Variable(let v):
            return v.getType()
        case .Literal(let li):
            return li.getType()
        default:
            print("This statement does not have a type, fatal error. Exiting test framework \(self.description)".lightRed.bold)
            exit(0)
        }
    }
    
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
