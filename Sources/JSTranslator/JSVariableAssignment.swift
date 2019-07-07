import Foundation

public class JSVariableAssignment : CustomStringConvertible {
    private let lhs : JSVariable
    private let rhs : JSNode
    private let isInstantiation: Bool
    
    public init(lhs : JSVariable , rhs: JSNode, isInstantiation : Bool = false) {
        self.lhs = lhs
        self.rhs = rhs
        self.isInstantiation = isInstantiation
    }
    
    public var description: String {
        
        var desc : String = ""
        
        if (isInstantiation)
        {
    
            guard case .FunctionCall(let fCall) = rhs else {
                print("non function call is not a valid instantiation")
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
                let varModifier = lhs.isConstant() ? "let" : "var"
                desc += varModifier
                desc += " " + lhs.description + " = " + randomVar + "['rVal']" + ";"
                return desc
            }
        default:
            break
        }

        let varModifier = lhs.isConstant() ? "let" : "var"
        desc += varModifier
        desc += " " + lhs.description + " = " + rhs.description + ";"
        return desc
    }
}
