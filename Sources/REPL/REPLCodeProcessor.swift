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
        case .identifier(let i):
            guard let rVar = repl.queryVariableMap(variable: i.name) else {
                print("Variable \(i.name) not in scope".lightRed.bold)
                return nil
            }
            varName = rVar.variableName
            varType = rVar.variableType
            varConst = rVar.varConstant
            newVar = false
        default:
            print("Invalid expression found on the LHS of an equal \(expr.rhs.description)".lightRed.bold)
            return nil
        }
        
        if let (res, resType) = try process_expr(expr: expr.rhs) {
            
            if resType != varType {
                print("Mismatch of types \(resType) != \(varType)".lightRed.bold)
                return nil
            }
            
            if !newVar && varConst{
                print("Cannot modify const variable \(varName)".lightRed.bold)
                return nil
            }
            
            let replVar = REPLVariable(variableName: varName, variableType: varType, variableValue: res, varConstant: varConst)
            repl.addVarToMap(replVar: replVar, name: varName)
            

            
            return (res, varType)
            
        } else {
            
            print("Invalid expression found on RHS of equal \(expr.rhs.description)".lightRed.bold)
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
        
    private func tryDeploy(binExp: BinaryExpression) throws -> Bool {
        var typeName = ""
        var variableName = ""
        
        switch (binExp.opToken) {
        case .equal:
            switch (binExp.lhs) {
            case .variableDeclaration(let vdec):
                typeName = vdec.type.name
                variableName = vdec.identifier.name
            default:
                break
            }
            
        default:
            break
        }
        
        if let rC = self.repl.queryContractInfo(contractName: typeName) {
            if let addr = try rC.deploy(expr: binExp, variable_name: variableName) {
                
                if addr == "ERROR" {
                    return true
                }
                
                let replVar =  REPLVariable(variableName: variableName, variableType: rC.getContractName(), variableValue: addr, varConstant: true)
                repl.addVarToMap(replVar: replVar, name: variableName)
                return true
            }
        }
    
        return false
    }
    
    public func process_expr(expr: Expression) throws -> (String, String)? {
        switch (expr) {
        case .binaryExpression(let binExp):

             // returns true if this was a deployment statement
             if try tryDeploy(binExp: binExp) {
                return nil
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
    
    private func process_arithmetic_expr(expr: BinaryExpression, op : REPLOperator) throws -> (String, String)? {
        
     
        guard let (e1, e1Type) = try process_expr(expr: expr.lhs) else {
            print("Could not process arithmetic expression".lightRed.bold)
            return nil
        }
    
        guard let (e2, e2Type) = try process_expr(expr: expr.rhs) else {
            print("Could not process arithmetic expression".lightRed.bold)
            return nil
        }
        
        if e2Type != "Int" || e1Type != "Int" {
            print("Invalid type passed to arithmetic addition operation".lightRed.bold)
            return nil
        }
        
        guard let e1Int = Int(e1) else {
            print("NaN found in arithmetic expression operands".lightRed.bold)
            return nil
        }
        
        guard let e2Int = Int(e2) else {
            print("NaN found in arithmetic expression operands".lightRed.bold)
            return nil
        }
        
        switch (op) {
        case .add:
            return ((e1Int + e2Int).description, "Int")
        case .divide:
            return ((e1Int / e2Int).description, "Int")
        case .minus:
            return ((e1Int - e2Int).description, "Int")
        case .power:
            return ((e1Int ^ e2Int).description, "Int")
        }
        
    }
    
    public func process_binary_expr(expr : BinaryExpression) throws -> (String, String)? {
        
        switch (expr.opToken) {
        case .dot:
            return process_dot_expr(expr: expr)
        case .equal:
            return try process_equal_expr(expr: expr)
        case .plus:
            return try process_arithmetic_expr(expr: expr, op: .add)
        case .minus:
            return try process_arithmetic_expr(expr: expr, op: .minus)
        case .divide:
            return try process_arithmetic_expr(expr: expr, op: .divide)
        case .power:
            return try process_arithmetic_expr(expr: expr, op: .power)
        default:
            print("This expression is not supported: \(expr.description)".lightRed.bold)
        }
        
        return nil
    }
}
