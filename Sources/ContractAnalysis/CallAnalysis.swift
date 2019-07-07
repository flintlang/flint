import AST
import Foundation

public class CallAnalyser {
    private var callerCapInfo : [String : [String]]
    private var stateCallerInfo : [String : [String]]
    private var anyPercentage: Int
    
    public init() {
        callerCapInfo = [:]
        stateCallerInfo = [:]
        anyPercentage = 0
    }
    
    private func computeAnyPercentage() -> Float {
        var totalNumberOfFuncs = 0
        
        if let numberOfFuncsUnderAny = callerCapInfo["any"]?.count {
            for (_, funcs) in callerCapInfo {
                totalNumberOfFuncs += funcs.count
            }
            
            return Float(numberOfFuncsUnderAny) / Float(totalNumberOfFuncs)
        }
        
        return 0
    }
    
    private func addStateToFunc(state : String, funcName : String) {
        if var funcs = stateCallerInfo[state] {
            funcs.append(funcName)
            self.stateCallerInfo[state] = funcs
        } else {
            self.stateCallerInfo[state] = []
            self.stateCallerInfo[state]?.append(funcName)
        }
    }
    
    private func addCallerCapToFunc(caller : String, funcName : String) {
        if var funcs = callerCapInfo[caller] {
            funcs.append(funcName)
            self.callerCapInfo[caller] = funcs
        } else {
            self.callerCapInfo[caller] = []
            self.callerCapInfo[caller]?.append(funcName)
        }
    }
    
    private func getContractBehaviourFunctions(members : [ContractBehaviorMember]) -> [FunctionDeclaration] {
        var funcs : [FunctionDeclaration] = []
        for m in members {
            switch (m) {
            case .functionDeclaration(let fdec):
                funcs.append(fdec)
            default:
                continue
            }
        }
        
        return funcs
    }

    public func analyse(ast : TopLevelModule) throws -> String {
        
        let decs = ast.declarations[2...]
        
        for d in decs {
            switch (d) {
            case .contractBehaviorDeclaration(let cBdec):
                analyseCallerInfo(cbDec: cBdec)
            default:
                continue
            }
        }
        
        let json_caller_cap_info = try JSONSerialization.data(withJSONObject: callerCapInfo, options: [])
        let string_json_caller_cap_info = String(data: json_caller_cap_info, encoding: .utf8)
        
        let json_state_call_info = try JSONSerialization.data(withJSONObject: stateCallerInfo, options: [])
        let string_json_state_call_info = String(data: json_state_call_info, encoding: .utf8)
        
        var callAnalysis : [String : String] = [:]
        callAnalysis["states"] = string_json_state_call_info
        callAnalysis["caller"] = string_json_caller_cap_info
        callAnalysis["anyPercent"] = (computeAnyPercentage() * 100).description
        
        let call_analysis_json = String(data: try JSONSerialization.data(withJSONObject: callAnalysis, options: []), encoding: .utf8)
        
        return call_analysis_json!
    }
    
    private func analyseCallerInfo(cbDec : ContractBehaviorDeclaration) {
        // for each caller, I need to add an entry for each of the funcs
        for caller in cbDec.callerProtections {
            let callerName = caller.name
            let contractFuncs = getContractBehaviourFunctions(members: cbDec.members)
            
            for fnc in contractFuncs {
                addCallerCapToFunc(caller: callerName, funcName: fnc.name)
            }
        }
        
        for state in cbDec.states {
            let stateName = state.name
            
            let contractFuncs = getContractBehaviourFunctions(members: cbDec.members)
            for fnc in contractFuncs {
                addStateToFunc(state: stateName, funcName: fnc.name)
            }
        }
        
    }
}
