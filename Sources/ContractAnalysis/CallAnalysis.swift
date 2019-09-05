import AST
import Foundation

public class CallAnalyser {
  private var callerCapInfo: [String: [String]]
  private var stateCallerInfo: [String: [String]]
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

  private func addStateToFunction(state: String, functionName: String) {
    if var functions = stateCallerInfo[state] {
      functions.append(functionName)
      self.stateCallerInfo[state] = functions
    } else {
      self.stateCallerInfo[state] = []
      self.stateCallerInfo[state]?.append(functionName)
    }
  }

  private func addCallerCapToFunction(caller: String, functionName: String) {
    if var functions = callerCapInfo[caller] {
      functions.append(functionName)
      self.callerCapInfo[caller] = functions
    } else {
      self.callerCapInfo[caller] = []
      self.callerCapInfo[caller]?.append(functionName)
    }
  }

  private func getContractBehaviourFunctions(members: [ContractBehaviorMember]) -> [FunctionDeclaration] {
    var functions: [FunctionDeclaration] = []
    for member in members {
      switch member {
      case .functionDeclaration(let functionDeclaration):
        functions.append(functionDeclaration)
      default:
        continue
      }
    }

    return functions
  }

  public func analyse(ast: TopLevelModule) throws -> String {

    let declarations = ast.declarations[2...]

    for declaration in declarations {
      switch declaration {
      case .contractBehaviorDeclaration(let contractBehaviorDeclaration):
        analyseCallerInfo(contractBehaviorDeclaration: contractBehaviorDeclaration)
      default:
        continue
      }
    }

    let jsonCallerCapInfo = try JSONSerialization.data(withJSONObject: callerCapInfo, options: [])
    let stringJsonCallerCapInfo = String(data: jsonCallerCapInfo, encoding: .utf8)

    let jsonStateCallInfo = try JSONSerialization.data(withJSONObject: stateCallerInfo, options: [])
    let stringJsonStateCallInfo = String(data: jsonStateCallInfo, encoding: .utf8)

    var callAnalysis: [String: String] = [:]
    callAnalysis["states"] = stringJsonStateCallInfo
    callAnalysis["caller"] = stringJsonCallerCapInfo
    callAnalysis["anyPercent"] = (computeAnyPercentage() * 100).description

    let callAnalysisJson = String(data: try JSONSerialization.data(withJSONObject: callAnalysis, options: []),
                                    encoding: .utf8)

    return callAnalysisJson!
  }

  private func analyseCallerInfo(contractBehaviorDeclaration: ContractBehaviorDeclaration) {
    // for each caller, I need to add an entry for each of the funcs
    for caller in contractBehaviorDeclaration.callerProtections {
      let callerName = caller.name
      let contractFunctions = getContractBehaviourFunctions(members: contractBehaviorDeclaration.members)

      for function in contractFunctions {
        addCallerCapToFunction(caller: callerName, functionName: function.name)
      }
    }

    for state in contractBehaviorDeclaration.states {
      let stateName = state.name

      let contractFunctions = getContractBehaviourFunctions(members: contractBehaviorDeclaration.members)
      for function in contractFunctions {
        addStateToFunction(state: stateName, functionName: function.name)
      }
    }

  }
}
