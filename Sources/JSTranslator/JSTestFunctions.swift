public class JSTestFunction : CustomStringConvertible {
    private let name: String
    private let stmts: [JSNode]

    public init(name: String,  stmts: [JSNode]) {
        self.name = name
        self.stmts = stmts
    }
    
    public func getFuncName() -> String {
        return self.name
    }
    
    public var description : String {
        let fncSignature = "async function " + name + "(t_contract) { \n"
        var body = ""
        let closeToken = "}"
        body += "   let 012assertResult = {} \n"
        for stm in stmts {
            body += "   " + stm.description + "\n"
        }
        let procR = "   process_test_result(012assertResult['result'], \"" + name  + "\"" + ")" + "\n"
        return fncSignature + body + procR + closeToken
    }
}
