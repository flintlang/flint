import AST
import Rainbow

public class REPLCodeProcessor {
    
    private let repl : REPL
    
    public init(repl : REPL) {
        self.repl = repl
    }
    
    private func process_equal_expr(expr : BinaryExpression) throws -> (String, String)? {
        
        var varName : String = ""
        var varType : String = ""
        var varConst : Bool = false
        var newVar : Bool = true
        
        switch (expr.lhs) {
        case .variableDeclaration(let vdec):
            varName = vdec.identifier.name
            varType = vdec.type.name
            varConst = vdec.isConstant
        default:
            print("Invalid expression found on the LHS of an equal \(expr.rhs.description)".lightRed.bold)
            return nil
        }
        
        if let (res, resType) = try process_expr(expr: expr.rhs) {
            
            if resType != varType {
                print("Mismatch of types \(resType) != \(varType)".lightRed.bold)
                return nil
            }
            
            let replVar = REPLVariable(variableName: varName, variableType: varType, variableValue: res, varConstant: varConst)
            repl.addVarToMap(replVar: replVar, name: varName)
            
            return (res, varType)
            
        } else {
            
            print("Invalid expression found on RHS of equal \(expr.lhs.description)".lightRed.bold)
        }
        
        return nil
    }
    
    private func process_dot_expr(expr: BinaryExpression) -> (String, String)? {
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
                let resType = rC!.getResultType(fnc: fCall.identifier.name)
                return (res, resType)
            }
        default:
            print("Not supported yet")
        }
        
        
        return nil
    }
    
    public func process_expr(expr: Expression) throws -> (String, String)? {
        switch (expr) {
        case .binaryExpression(let binExp):
            if let (rC, variableName) = check_if_instantiation(assignment: binExp) {
                if let addr = try rC.deploy(expr: binExp, variable_name: variableName) {
                    let replVar =  REPLVariable(variableName: variableName, variableType: rC.getContractName(), variableValue: addr, varConstant: true)
                    repl.addVarToMap(replVar: replVar, name: variableName)
                    return nil
                }
             }
    
             if let (res, type) = try process_binary_expr(expr: binExp) {
                return (res, type)
             }
            
        case .identifier(let i):
            if let rVar = repl.queryVariableMap(variable: i.name) {
                return (rVar.variableValue, rVar.variableType)
            } else {
                print("Variable \(i.name) not in scope".lightRed.bold)
            }
            
        case .literal(let li):
            switch (li.kind) {
            case .literal(let lit):
                switch (lit) {
                case .string(let s):
                    return (s, "String")
                case .decimal(let dec):
                    switch (dec) {
                    case .integer(let i):
                        return (i.description, "Int")
                    default:
                        print("Floating point numbers are not supported".lightRed.bold)
                    }
                case .address(let a):
                    return (a, "Address")
                case .boolean(let b):
                    return (b.rawValue, "Bool")
                }
            default:
                print("ERROR: Invalid token found \(li.description)".lightRed.bold)
            }
        default:
            print("Syntax is not supported".lightRed.bold)
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
