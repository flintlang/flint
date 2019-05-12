import AST
import Rainbow

public class REPLCodeProcessor {
    
    private let repl : REPL
    
    public init(repl : REPL) {
        self.repl = repl
    }
    
    private func process_equal_expr(expr : BinaryExpression) -> String? {
        
        var varName : String = ""
        var varType : String = ""
        
        switch (expr.rhs) {
        case .variableDeclaration(let vdec):
            varName = vdec.identifier.name
            varType = vdec.type.name
        default:
            print("Invalid expression found on the LHS of an equal \(expr.rhs.description)".lightRed.bold)
            return nil
        }
        
        var res : String? = nil
        switch (expr.lhs) {
        case .binaryExpression(let binExp):
            res = process_binary_expr(expr: binExp)
        default:
            print("Invalid expression found on the RHS of an equal \(expr.lhs.description)".lightRed.bold)
            return nil
        }
        
        if let val = res {
            
            return val
        }
        
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
    
    public func process_expr(expr: Expression) throws -> String? {
        switch (expr) {
        case .binaryExpression(let binExp):
            if let (rC, variableName) = check_if_instantiation(assignment: binExp) {
                if let addr = try rC.deploy(expr: binExp, variable_name: variableName) {
                    let replVar =  REPLVariable(variableName: variableName, variableType: rC.getContractName(), variableValue: addr, varConstant: true)
                    repl.addVarToMap(replVar: replVar, name: variableName)
                    return nil
                }
             }
    
             if let res = process_binary_expr(expr: binExp) {
                return res
             }
        case .identifier(let i):
            print(i)
        default:
            print("Syntax is not supported".lightRed.bold)
            return nil
        }
                
        return nil
    }
    
    public func process_binary_expr(expr : BinaryExpression) -> String? {
                
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
    
    private func check_if_instantiation(assignment : BinaryExpression) -> (REPLContract, String)? {
        var typeName = ""
        var variableName = ""
        
        switch (assignment.opToken) {
        case .equal:
            switch (assignment.lhs) {
            case .variableDeclaration(let vdec):
                typeName = vdec.type.name
                variableName = vdec.identifier.name
            default:
                break
            }
            
        default:
            break
        }
        
        if let rContract = self.repl.queryContractInfo(contractName: typeName) {
            return (rContract, variableName)
        } else {
            return nil
        }
    }
}
