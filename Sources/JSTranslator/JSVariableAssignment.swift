import Foundation

public class JSVariableAssignment : CustomStringConvertible {
    private let lhs : String
    private let isConstant: Bool
    private let rhs : JSNode
    private let isInstantiation: Bool
    private let resultType: String
    
    public init(lhs: String, rhs: JSNode, isConstant: Bool, resultType: String, isInstantiation : Bool = false) {
        self.lhs = lhs
        self.rhs = rhs
        self.isConstant = isConstant
        self.isInstantiation = isInstantiation
        self.resultType = resultType
    }
    
    public var description: String {
        
        var desc : String = ""
        
        if (isInstantiation)
        {
            // check that the rhs is an actual function call
            guard case .FunctionCall(let fCall) = rhs else {
                print("Function call is not a valid instantiation")
                exit(0)
            }
            
            desc += fCall.generateTestFrameworkConstructorCall() + "\n"
            
            desc += "   //"
            
        }
        
        switch (rhs) {
        case .FunctionCall(let fCall):
            if fCall.generateExtraVarAssignment() {
                let randNum = Int.random(in: 0..<Int.max)
                let randomVar = "_X" + randNum.description
                desc += "let " + randomVar + " = " + rhs.description + ";"
                desc += "\n"
                desc += "   "
                let varModifier = isConstant ? "let" : "var"
                desc += varModifier
                desc += " " + lhs.description + " = " + randomVar + "['rVal']" + ";"
                return desc
            }
        default:
            break
        }

        let varModifier = isConstant ? "let" : "var"
        desc += varModifier
        desc += " " + lhs.description + " = " + rhs.description + ";"
        return desc
    }
}
