import Foundation

public class JSVariableAssignment : CustomStringConvertible {
    private let lhs : String
    private let isConstant: Bool
    private let rhs : JSNode
    private let isInstantiation: Bool
    
    public init(lhs: String, rhs: JSNode, isConstant: Bool, isInstantiation : Bool = false) {
        self.lhs = lhs
        self.rhs = rhs
        self.isConstant = isConstant
        self.isInstantiation = isInstantiation
    }
    
    public var description: String {
        
        var desc : String = ""
        
        if (isInstantiation)
        {
            guard case .FunctionCall(let fCall) = rhs else {
                print("Function call is not a valid instantiation")
                exit(0)
            }
            
            desc += fCall.generateTestFrameworkConstructorCall() + "/n"
            
            desc += "//"
            
        }

        let varModifier = isConstant ? "let" : "var"
        desc += varModifier
        desc += " " + lhs.description + " = " + rhs.description + ";"
        return desc
    }
}
