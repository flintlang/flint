public class JSFunctionCall {
    private let contractCall : Bool
    private let transactionMethod : Bool
    private let isAssert: Bool
    private let functionName: String
    private let args : [JSNode]
    private let contractName : String
    
    public init(contractCall: Bool, transactionMethod: Bool, isAssert: Bool, functionName: String, contractName : String, args : [JSNode]) {
        self.contractCall = contractCall
        self.transactionMethod = transactionMethod
        self.isAssert = isAssert
        self.functionName = functionName
        self.contractName = contractName
        self.args = args
    }
}
