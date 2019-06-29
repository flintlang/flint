public struct ContractFuncInfo {
    private var resultType : String
    private var payable : Bool
    
    public init(resultType : String, payable: Bool) {
        self.resultType = resultType
        self.payable = payable
    }
    
    public func getType() -> String {
       return resultType
    }
    
    public func isPayable() -> Bool {
        return payable
    }
}
