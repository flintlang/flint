public class JSFunctionCall : CustomStringConvertible {
    
    private let contractCall : Bool
    private let transactionMethod : Bool
    private let isAssert: Bool
    private let functionName: String
    private let args : [JSNode]
    private let contractName : String
    private let resultType : String
    
    // return type of function call is required
    
    public init(contractCall: Bool, transactionMethod: Bool, isAssert: Bool, functionName: String, contractName : String, args : [JSNode], resultType: String = "") {
        self.contractCall = contractCall
        self.transactionMethod = transactionMethod
        self.isAssert = isAssert
        self.functionName = functionName
        self.contractName = contractName
        self.args = args
        self.resultType = resultType
    }
    
    public func generateTestFrameworkConstructorCall() -> String {
        if args.count == 0 {
            return ""
        }
        var desc = "await transactional_method(t_contract, \'testFrameworkConstructor\', "
        desc += "[" + create_arg_list() + "]" + ")"
        return desc
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
                if (resultType == "Int") {
                    fCall = "call_method_int(t_contract, " + "'" + self.functionName + "'"
                } else if (resultType == "String") {
                    fCall = "call_method_string(t_contract, " + "'" + self.functionName + "'"
                } else if (resultType == "Address") {
                    fCall = "call_method_string(t_contract, " + "'" + self.functionName + "'"
                }
               
                if args.count > 0 {
                    fCall += "," + create_arg_list() + ")"
                } else {
                    fCall += ", [])"
                }
            }
        } else {
            
            var assertFuncs : [String] = []
            assertFuncs.append("assertCallerSat")
            assertFuncs.append("assertCallerUnsat")
            assertFuncs.append("assertCanCallInThisState")
            assertFuncs.append("assertCantCallInThisState")
            
            let isCallerOrStateFunc = assertFuncs.contains(functionName)
            
            if isCallerOrStateFunc {
                fCall += "await "
            }
            
            if isAssert {
                fCall += self.functionName + "(" + "assertResult012, "
            } else {
                fCall += self.functionName + "("
            }
            
            if args.count > 0 {
                fCall += create_arg_list()
            }
            
            if args.count < 2 && isCallerOrStateFunc {
                fCall += ", []"
            }
            
            if isCallerOrStateFunc {
                fCall += ", t_contract"
            }
            
            fCall += ")"
        }
    
        return fCall
    }
}
