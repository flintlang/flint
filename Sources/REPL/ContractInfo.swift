struct ContractInfo {
    let contractName : String
    let contractAddress : String
    let contractFilePath : String

    public init(contractName : String, contractAddress: String, contractFilePath : String) {
        self.contractName = contractName
        self.contractAddress = contractAddress
        self.contractFilePath = contractFilePath
    }
}
