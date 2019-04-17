public class JSFunctionCall : CustomStringConvertible {
    
    private let contractCall : Bool
    private let transactionMethod : Bool
    private let isAssert: Bool
    private let functionName: String
    private let args : [JSNode]
    private let contractName : String
    
    // return type of function call is required
    
    public init(contractCall: Bool, transactionMethod: Bool, isAssert: Bool, functionName: String, contractName : String, args : [JSNode]) {
        self.contractCall = contractCall
        self.transactionMethod = transactionMethod
        self.isAssert = isAssert
        self.functionName = functionName
        self.contractName = contractName
        self.args = args
    }
    
    private func create_arg_list() -> String {
        var argList = ""
        let lastIndex = args.count - 1
        var counter = 0
        for a in args {
            if counter == lastIndex {
                argList += a.description
                continue
            }
            argList +=  a.description + ", "
            counter += 1
        }
    
        return argList
    }
    
   
    public var description: String {
        // this is where you actually call the right
        var fCall = ""
        
        if (contractCall) {
            if (transactionMethod) {
                fCall = "await transactional_method(t_contract, " + "'" + self.functionName + "'"
                if args.count > 0 {
                    fCall += "," + "[" + create_arg_list() + "]" + ")"
                } else {
                    fCall += ", [])"
                }
            } else {
                fCall = "call_method_int(t_contract, " + "'" + self.functionName + "'"
                if args.count > 0 {
                    fCall += "," + create_arg_list() + ")"
                } else {
                    fCall += ", [])"
                }
            }
        } else {
            
            if isAssert {
                fCall += self.functionName + "(" + "012assertResult, "
            } else {
                fCall += self.functionName + "("
            }
            
            
            if args.count > 0 {
                fCall += create_arg_list() + ")"
            } else {
                fCall += ")"
            }
            
        }
    
        return fCall
    }
}
