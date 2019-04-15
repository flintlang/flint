public class JSFunctionCall {
    private let contractCall : Bool
    private let transactionMethod : Bool
    private let isAssert: Bool
    private let functionName: String
    
    public init(contractCall: Bool, transactionMethod: Bool, isAssert: Bool, functionName: String) {
        self.contractCall = contractCall
        self.transactionMethod = transactionMethod
        self.isAssert = isAssert
        self.functionName = functionName
    }
}
