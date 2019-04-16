public class JSTestFunction : CustomStringConvertible {
    private let name: String
    private let stmts: [JSNode]

    public init(name: String,  stmts: [JSNode]) {
        self.name = name
        self.stmts = stmts
    }
    
    public var description : String {
        let fncSignature = "async function " + name + "() { \n"
        var body = ""
        let closeToken = "}"
        for stm in stmts {
            body += "   " + stm.description + "\n"
        }
        return fncSignature + body + closeToken
    }
}
