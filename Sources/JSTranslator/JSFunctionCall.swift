import Foundation

public class JSFunctionCall : CustomStringConvertible {
    
    private let contractCall : Bool
    private let transactionMethod : Bool
    private let isAssert: Bool
    private let functionName: String
    private let args : [JSNode]
    private let contractName : String
    private let resultType : String
    private let eventInformation : ContractEventInfo?
    private let isPayable : Bool
    private let weiAmount : Int?
    
    public init(contractCall: Bool, transactionMethod: Bool, isAssert: Bool, functionName: String, contractName : String, args : [JSNode], resultType: String = "", isPayable: Bool, eventInformation : ContractEventInfo? = nil, weiAmount : Int? = nil) {
        self.contractCall = contractCall
        self.transactionMethod = transactionMethod
        self.isAssert = isAssert
        self.functionName = functionName
        self.contractName = contractName
        self.args = args
        self.resultType = resultType
        self.isPayable = isPayable
        self.weiAmount = weiAmount
        self.eventInformation = eventInformation
    }
    
    
    public func generateExtraVarAssignment() -> Bool {
        return transactionMethod && (resultType != "")
    }
    
    public func generateTestFrameworkConstructorCall() -> String {
        if args.count == 0 {
            return ""
        }
        var desc = "await transactional_method(t_contract, \'testFrameworkConstructor\', "
        desc += "[" + create_arg_list() + "]" + ")"
        return desc
    }
    
    private func create_arg_list(args: [JSNode]) -> String {
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
                // I need to switch between the different types that are possible and then generate the right return value
                if (resultType == "Int") {
                    fCall = "await transactional_method_int(t_contract, " + "'" + self.functionName + "'"
                } else if (resultType == "String") {
                    fCall = "await transactional_method_string(t_contract, " + "'" + self.functionName + "'"
                } else if (resultType == "Address") {
                    fCall = "await transactional_method_string(t_contract, " + "'" + self.functionName + "'"
                } else {
                    fCall = "await transactional_method_void(t_contract, " + "'" + self.functionName + "'"
                }
                
                if args.count > 0 {
                    fCall += "," + "[" + create_arg_list() + "], "
                } else {
                    fCall += ", [], "
                }
                
                if isPayable {
                    if let weiAmt = weiAmount {
                        fCall += "{value:" + weiAmt.description + "}"
                    } else {
                        print("Found no value assocaited with the wei paramater. Function Call \(functionName)")
                        exit(0)
                    }
                    
                } else {
                    fCall += "{}"
                }
                
                fCall += ")"
                
            } else {
                
                if (resultType == "Int") {
                    fCall = "call_method_int(t_contract, " + "'" + self.functionName + "'"
                } else if (resultType == "String") {
                    fCall = "call_method_string(t_contract, " + "'" + self.functionName + "'"
                } else if (resultType == "Address") {
                    fCall = "call_method_string(t_contract, " + "'" + self.functionName + "'"
                } else {
                    print("Calling a constant function with no return type, this is not allowed".lightRed.bold)
                    print("Function: \(self.functionName)".lightRed.bold)
                    exit(0)
                }

                if args.count > 0 {
                    fCall += ", [" + create_arg_list() + "])"
                } else {
                    fCall += ", []);"
                }
            }
        } else {
            
            let assertFuncs : [String] = JSTranslator.testSuiteFuncs
            
            let isCallerOrStateFunc = assertFuncs.contains(functionName)
            
            if isCallerOrStateFunc {
                fCall += "await "
            }
            
            if isAssert {
                fCall += self.functionName + "(" + "assertResult012, "
            } else {
                fCall += self.functionName + "("
            }
            
            if functionName.contains("assertEventFired") {
                if let eventInfo = eventInformation {
                    let event_args = args[1...]
                    var event_filter = ""
                    var event_name = ""
                    do {
                        event_filter = try eventInfo.create_event_arg_object(args: Array(event_args))
                        event_name = args[0].description
                    } catch {
                        print("Failed to construct event filter")
                        exit(0)
                    }
                    fCall += "\"" + event_name + "\", "
                    fCall += event_filter
                } else {
                    print("No associated event information with this function call")
                    exit(0)
                }
            } else {
                
                if isCallerOrStateFunc {

                    // I need to now verify
                    if args.count > 0 {
                        fCall +=  args[0].description
                    }
                    
                    if args.count < 2 {
                        fCall += ", []"
                    } else {
                        fCall += ", [" + create_arg_list(args: Array(args[1...])) + "]"
                    }
    
                } else {
                    
                    if args.count > 0 {
                        fCall += create_arg_list()
                    }
                }
                

            }
            
            if isCallerOrStateFunc {
                fCall += ", t_contract"
            }
            
            fCall += ");"
        }
    
        return fCall
    }
}
