public struct REPLVariable {
    public let variableName : String
    public let variableType : String
    public let variableValue : String
    
    public init(variableName : String, variableType : String, variableValue : String) {
        self.variableName = variableName
        self.variableType = variableType
        self.variableValue = variableValue
    }
}
