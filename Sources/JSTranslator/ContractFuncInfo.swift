public struct ContractFuncInfo {
    private var resultType : String
    
    public init(resultType : String) {
        self.resultType = resultType
    }
    
    public func getType() -> String {
       return resultType
    }
}
