import AST
import Rainbow

public class REPLCodeProcessor {
    
    private let repl : REPL
    
    public init(repl : REPL) {
        self.repl = repl
    }
    
    private func process_equal_expr(expr : BinaryExpression) -> String? {
        
        return nil
    }
    
    private func process_dot_expr(expr: BinaryExpression) -> String? {
        var rC : REPLContract? = nil
        var variableName : String = ""
        
        switch (expr.lhs) {
        case .identifier(let i):
            if let rVar = self.repl.queryVariableMap(variable: i.name) {
                if let rContract = self.repl.queryContractInfo(contractName: rVar.variableType) {
                    rC = rContract
                    variableName = i.name
                } else {
                    print("Variable is not mapped to a contract")
                    return nil
                }
            } else {
                print("Variable \(i.name) not in scope")
            }
        default:
            print("Only identifiers are allowed on the LHS of a dot expression")
        }
        
        switch (expr.rhs) {
        case .functionCall(let fCall):
            if let res = rC?.run(fCall: fCall, instance: variableName) {
                return res
            }
        default:
            print("Not supported yet")
        }
        
        
        return nil
    }
    
    public func process_expr(expr : BinaryExpression) -> String? {
        switch (expr.opToken) {
        case .dot:
            return process_dot_expr(expr: expr)
        case .equal:
            return process_equal_expr(expr: expr)
        case .plus:
            print("+")
        case .minus:
            print("-")
        case .divide:
            print("d")
        case .power:
            print("e")
        default:
            print("This expression is not supported: \(expr.description)".lightRed.bold)
        }
        
        return nil
    }
}
