public class REPL {
    let contractInfoMap : [String : ContractInfo] = [:]
    
    public init(contractFilePath: String, contractAddress : String = "") {
       print(contractFilePath)
       print(contractAddress)
    }
    
    public func run() throws {
        print("repl is running")
    }
    
}
