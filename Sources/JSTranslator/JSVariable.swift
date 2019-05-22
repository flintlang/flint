public class JSVariable : CustomStringConvertible {
    private let variable : String
    private let type : String
    
    public init(variable: String, type: String) {
        self.variable = variable
        self.type = type
    }
    
    public func getType() -> String {
        return type
    }
    
    public var description: String {
        return variable
    }
}
