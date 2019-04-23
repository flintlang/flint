public struct ContractFuncInfo {
    private var type : String
    
    public init(type : String) {
        self.type = type
    }
    
    public func getType() -> String {
       return type
    }
}
