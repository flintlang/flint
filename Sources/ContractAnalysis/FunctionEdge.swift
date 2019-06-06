public struct FunctionEdge {
    let Name : String
    let Payable : Bool
    let SendMoney : Bool
    let IsMutating : Bool
    
    public init(name: String, payable: Bool, sendMoney: Bool, isMutating: Bool) {
        Name = name
        Payable = payable
        SendMoney = sendMoney
        IsMutating = isMutating
    }
}
