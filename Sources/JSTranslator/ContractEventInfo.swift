import Foundation

public struct ContractEventInfo {
    private let name : String
    //mapping from event argument to type of argument
    private let event_args : [(String, String)]
    public init(name : String, event_args : [(String, String)]) {
        self.name = name
        self.event_args = event_args
    }
    
    public func create_event_arg_object(args : [JSNode]) throws -> String {
        
        var res_dict : [String : String] = [:]
        var numOfArg : Int = 0
        
        if args.count != event_args.count {
            print("Incorrect number of arguments passed as an argument for event filter")
            exit(0)
        }
        
        for a in args {
            switch (a) {
            case .FunctionCall(let fCall):
                res_dict[event_args[numOfArg].0] = fCall.description
            case .Literal(let li):
                switch (li) {
                case .Integer(let i):
                    res_dict[event_args[numOfArg].0] = i.description
                case .String(let s):
                    res_dict[event_args[numOfArg].0] = s.description
                }
            case .Variable(let va):
                res_dict[event_args[numOfArg].0] = va.description
            default:
                print("Incorrect expression passed as an argument for event filter")
                exit(0)
            }
        
            numOfArg += 1
        }
        
        let json_res_dict = String(data: try JSONSerialization.data(withJSONObject: res_dict, options: []), encoding: .utf8)
        
        return json_res_dict!
    }
    
    public func getEventName() -> String {
        return name
    }
}
