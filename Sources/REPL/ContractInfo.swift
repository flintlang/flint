struct ContractInfo {
  let contractName: String
  let contractAddress: String
  let contractFilePath: String
  let contractABI: String
  let contractSource: String

  public init(contractName: String,
              contractAddress: String,
              contractFilePath: String,
              contractABI: String,
              contractSource: String) {
    self.contractName = contractName
    self.contractAddress = contractAddress
    self.contractFilePath = contractFilePath
    self.contractABI = contractABI
    self.contractSource = contractSource
  }
}
