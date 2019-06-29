public class JSVariable : CustomStringConvertible {
    private let variable : String
    
    public init(variable: String) {
        self.variable = variable
    }
    
    public var description: String {
        return variable
    }
}
