import AST
import Foundation
import Lexer
import Parser

public class FunctionTranslator {
    
    private let jst : JSTranslator
    private var varMap : [String: JSVariable] = [:]
    private let NIL_TYPE = "nil"
    private var error_array : [String] = []
    
    public init(jst: JSTranslator) {
        self.jst = jst
    }
    
    public func translate(funcDec : FunctionDeclaration) -> JSTestFunction? {
        let s = processContractFunction(fdec: funcDec)
        //print(error_array)
        return s
    }
    
    private func processContractFunction(fdec: FunctionDeclaration) -> JSTestFunction?
    {
        let fSignature : FunctionSignatureDeclaration = fdec.signature
        
        let fName : String = fSignature.identifier.name
        
        var jsStmts : [JSNode] = []
        
        // if this is not a test function then do not process
        if (!fName.lowercased().contains("test"))
        {
            return nil
        }
        
        let body : [Statement] = fdec.body
        
        for stmt in body {
            switch (stmt) {
            case .expression(let expr):
                if let jsExpr = process_expr(expr: expr) {
                     jsStmts.append(jsExpr)
                }

            default:
                continue
            }
        }
        
        return JSTestFunction(name: fName, stmts: jsStmts)
    }
    
    private func process_expr(expr : Expression) -> JSNode?
    {
        switch (expr) {
        case .binaryExpression(let binExp):
            return process_binary_expression(binExp: binExp)
        case .functionCall(let fCall):
            return process_func_call(fCall: fCall)
    
        default:
            print("Expression \(expr.description) is not supported yet".lightRed.bold)
            exit(0)
        }
        
        return nil
    }
    
    private func process_binary_expression(binExp: BinaryExpression) -> JSNode? {
        switch (binExp.opToken) {
        case .equal:
            return process_assignment_expr(binExp: binExp)
        case .dot:
            return process_dot_expr(binExpr: binExp)
        default:
            error_array.append("Test framework does not yet support expressions with operator \(binExp.description) at \(binExp.sourceLocation)".lightRed.bold)
            return nil
        }
    }
    
    private func process_dot_expr(binExpr : BinaryExpression) -> JSNode? {
        var lhsName : String = ""
        var rhsNode : JSNode? = nil
        
        switch (binExpr.lhs) {
        case .identifier(let i):
            lhsName = i.name
        default:
            break
        }
        
        switch (binExpr.rhs) {
        case .functionCall(let fCall):
            guard let _ = jst.contractFunctionInfo[fCall.identifier.name] else {
                // function does not exist in contract (currently support single contract deploment)
                error_array.append("Function \(fCall.identifier.name) not found in contract at \(fCall.sourceLocation)".lightRed.bold)
                return nil
            }
            rhsNode = process_func_call(fCall: fCall, lhsName: lhsName)
            
        case .identifier(let i):
            // currently we only support querying of events via this syntax
            guard let _ = jst.contractEventInfo[i.name] else {
                error_array.append("Only events are supported on the rhs of dot expression at \(i.sourceLocation)".lightRed.bold)
                return nil
            }
            rhsNode = .Variable(JSVariable(variable: i.name, type: "event", isConstant: false))
        default:
            error_array.append("Unsupported expression found on the RHS of dot expr \(binExpr.rhs) at \(binExpr.sourceLocation)".lightRed.bold)
            return nil
        }
        
        return rhsNode!
    }
    
    private func process_assignment_expr(binExp : BinaryExpression) -> JSNode? {
        var rhsNode : JSNode? = nil
        var lhsNode : JSVariable? = nil
        var isInstantiation : Bool = false
        
        switch (binExp.lhs) {
        case .variableDeclaration(let vdec):
            let name = vdec.identifier.name
            let isConst = vdec.isConstant
            var varType = self.NIL_TYPE
            switch (vdec.type.rawType) {
            case .basicType(let rt):
                switch (rt) {
                case .string:
                    varType = "String"
                case .int:
                    varType = "Int"
                case .address:
                    varType = "Address"
                case .bool:
                    varType = "Bool"
                case .void:
                    varType = self.NIL_TYPE
                case .event:
                    error_array.append("Error, event cannot be part of a variable declaration at \(binExp.lhs.sourceLocation)".lightRed.bold)
                    return nil
                }
            default:
               varType = vdec.type.rawType.name
            }

            lhsNode = JSVariable(variable: name, type: varType, isConstant: isConst)
            if let _ = varMap[name] {
                error_array.append("Redeclaration of variable \(name) at \(binExp.lhs.sourceLocation)".lightRed.bold)
                return nil
            }
            
            varMap[name] = lhsNode
        case .identifier(let i):
            
            guard let lhsN = varMap[i.name] else {
                error_array.append("Variable \(i.name) not in scope at \(binExp.sourceLocation)".lightRed.bold)
                return nil
            }
            
            if lhsN.isConstant() {
                error_array.append("Variable \(i.name) marked as const, cannot reassign at \(binExp.sourceLocation)".lightRed.bold)
                return nil
            }
            
            lhsNode = lhsN
    
        default:
            error_array.append("Found invalid variable declaration in assignment expression \(binExp.lhs.description) at \(binExp.sourceLocation)" .lightRed.bold)
            return nil
        }
        
        switch (binExp.rhs) {
        case .binaryExpression(let binExpr):
            rhsNode = process_binary_expression(binExp: binExpr)
            
        case .functionCall(let fCall):
            isInstantiation = !fCall.identifier.name.lowercased().contains("assert") && !jst.contractFunctionNames.contains(fCall.identifier.name) && fCall.identifier.name.lowercased().contains(jst.getContractName().lowercased())
            rhsNode = process_func_call(fCall: fCall)
            
        case .literal(let li):
            if let lit = extract_literal(literalToken: li) {
                rhsNode = lit
            } else {
               error_array.append("Could not find valid literal on the RHS of expression \(li.description) at \(binExp.rhs.sourceLocation)".lightRed.bold)
                return nil
            }
        default:
            break
        }
        
        if rhsNode!.getType() != lhsNode!.getType() {
            error_array.append("Mismatch of types at \(binExp.sourceLocation)")
            return nil
        }
  

        return .VariableAssignment(JSVariableAssignment(lhs: lhsNode!, rhs: rhsNode!, isInstantiation: isInstantiation))
    }
    
    private func extract_literal(literalToken : Token) -> JSNode? {
        switch (literalToken.kind) {
        case .literal(let lit):
            switch (lit) {
            case .decimal(let dec):
                switch (dec) {
                case .integer(let val):
                    return .Literal(.Integer(val))
                default:
                    break
                }
            case .address(let s):
                return .Literal(.String(s))
            case .string(let s):
                return .Literal(.String(s))
            case .boolean(let b):
                return .Literal(.Bool(b.rawValue))
            }
        default:
            return nil
        }
        
        return nil
    }
    
    private func process_func_call_args(args : [FunctionArgument]) -> [JSNode] {
        
        var jsArgs : [JSNode] = []
        
        for a in args {
            // create a JSNode for each of these but for now we will just do variables
            switch (a.expression)
            {
            case .identifier(let i):
                // I should look up the if the variable exists
                if let jsVar = varMap[i.name] {
                    jsArgs.append(.Variable(jsVar))
                } else {
                    error_array.append("Variable \(i.name) not in scope at \(i.sourceLocation)")
                }
            
            case .literal(let l):
                if let lit = extract_literal(literalToken: l) {
                    jsArgs.append(lit)
                } else {
                    error_array.append("Invalid literal found at \(l.sourceLocation)")
                }
            case .binaryExpression(let be):
                if let func_expr = process_binary_expression(binExp: be) {
                    jsArgs.append(func_expr)
                } else {
                    error_array.append("Invalid expression found in function call argument \(be) at \(be.sourceLocation)")
                }
            default:
                break
            }
        }
        
        return jsArgs
    }
    
    private func checkFuncArgs(fArgs : [FunctionArgument]) -> Bool {
        return true
    }
    
    
    private func extract_int_lit_from_expr(expr : Expression) -> Int? {
        switch (expr) {
        case .literal(let li):
            switch (li.kind) {
            case .literal(let lit):
                switch (lit) {
                case .decimal(let dec):
                    switch (dec) {
                    case .integer(let i):
                        return i
                    default:
                        return nil
                    }
                default:
                    return nil
                }
            default:
                return nil
            }
        default:
            return nil
        }
    }
    
    private func get_wei_val(args : [FunctionArgument]) -> (Int, Int)? {
        for (i, a) in args.enumerated() {
            if let label = a.identifier {
                if (label.name == "_wei") {
                    guard let wei_val = extract_int_lit_from_expr(expr: a.expression) else {
                        print("Non numeric wei value found: \(a.expression.description)".lightRed.bold)
                        exit(0)
                    }
                    
                    return (i, wei_val)
                }
            }
        }
        
        return nil
    }
    
    private func process_func_call(fCall : FunctionCall, lhsName: String = "") -> JSNode? {
        let fName : String = fCall.identifier.name
        var isTransaction = false
        var resultType: String = self.NIL_TYPE
        
        if let _ = jst.contractFunctionInfo[fName] {
            
        } else if JSTranslator.allFuncs.contains(fName) {
            
        } else if jst.getContractName() == fName{
            resultType = jst.getContractName()
            
        } else {
            error_array.append("Function \(fCall.identifier.name) does not exist at \(fCall.sourceLocation)")
            return nil
        }
  
        if let isFuncTransaction = jst.isFuncTransaction[fName] {
            isTransaction = isFuncTransaction
        }
        
        var isPayable : Bool = false
        if let funcInfo = jst.contractFunctionInfo[fName] {
            resultType = funcInfo.getType()
            isPayable = funcInfo.isPayable()
        }
        
        var weiVal : Int? = nil
        var funcCallArgs = fCall.arguments
        
        if !checkFuncArgs(fArgs: funcCallArgs) {
            error_array.append("Mismatch argument in function call \(fCall.identifier.name) at \(fCall.sourceLocation)")
            return nil
        }
        
        
        if isPayable {
            guard let (idx, weiAmt) = get_wei_val(args: fCall.arguments) else {
                print("Payable function found but wei has not been sent, add wei with argument label _wei. Function Name: \(fCall.identifier.name)".lightRed.bold)
                exit(0)
            }
            weiVal = weiAmt
            var firstHalf : [FunctionArgument]
            var secondHalf : [FunctionArgument]
            
            if idx > 0 {
                firstHalf = Array(funcCallArgs[...(idx-1)])
                secondHalf = Array(funcCallArgs[(idx+1)...])
            } else {
                firstHalf = []
                secondHalf = Array(funcCallArgs[(idx+1)...])
            }
            
            let completeArray = firstHalf + secondHalf
            funcCallArgs = completeArray
        }
 
        let funcArgs = process_func_call_args(args: funcCallArgs)
        
        var contractEventInfo : ContractEventInfo? = nil
        if fName.contains("assertEventFired") {
            if let eventInfo = jst.contractEventInfo[funcArgs[0].description] {
                contractEventInfo = eventInfo
            } else {
                print("The event " + funcArgs[0].description + " does not exist")
                exit(0)
            }
        }
        
        let isAssert = fName.lowercased().contains("assert")
        
        return .FunctionCall(JSFunctionCall(contractCall: jst.contractFunctionNames.contains(fName), transactionMethod: isTransaction, isAssert: isAssert, functionName: fName, contractName: lhsName, args: funcArgs, resultType: resultType, isPayable: isPayable, eventInformation: contractEventInfo, weiAmount: weiVal))
    }

    
}
