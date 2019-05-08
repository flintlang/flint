public class REPL {
    let contractInfoMap : [String : ContractInfo] = [:]
    
    public init(contractFilePath: String, contractAddress : String = "") {
    }
    
    public func run() throws {
        while let input = readLine() {
            print(input)
        }
    }
    
}
