import JSTranslator
import AST
import Parser
import Lexer
import Diagnostic
import Foundation

public class REPLContract{
    private var isFuncTransaction : [String:Bool]
    private var contractFunctionNames : [String]
    private var contractFunctionInfo : [String : ContractFuncInfo]
    private var contractEventInfo : [String : ContractEventInfo]
    private var instanceToAddress : [String : String]
    private let contractFilePath : String
    private let contractName : String
    private let abi: String
    private let bytecode: String
    private let repl: REPL

    
    public init(contractFilePath : String, contractName : String, abi: String, bytecode: String, repl : REPL) {
        self.contractFilePath = contractFilePath
        self.contractName = contractName
        self.contractFunctionInfo = [:]
        self.contractEventInfo = [:]
        self.contractFunctionNames = []
        self.isFuncTransaction  = [:]
        self.instanceToAddress = [:]
        self.abi = abi
        self.bytecode = bytecode
        self.repl = repl
        loadContract()
    }
    

    public func run(fCall : FunctionCall) -> String? {
        
        return ""
    }
    
    private func process_func_call_args(args : [FunctionArgument]) -> ([String], Bool) {
    
        var result_args : [String] = []
        
        for a in args {
            switch (a.expression) {
            case .binaryExpression(let binExp):
                switch (binExp.opToken) {
                case .dot:
                    switch (binExp.lhs) {
                    case .identifier(let i):
                        if let rVar = repl.queryVariableMap(variable: i.name) {
                            let contractType = rVar.variableType
                            if let rContract = repl.queryContractInfo(contractName: contractType) {
                                switch (binExp.rhs) {
                                case .functionCall(let fc):
                                    if let result = rContract.run(fCall: fc) {
                                        result_args.append(result)
                                    } else {
                                        print("Was not able to run \(fc.description)")
                                        return ([], true)
                                    }
                                default:
                                    print("Only function calls on rhs of dot expressions are currently supported")
                                    return ([], true)
                                }
                            }
                        } else {
                            print("Variable \(i.name) is not in scope.")
                            return ([], true)
                        }
                    default:
                        print("Identfier not found on lhs of dot expression")
                        return ([], true)
                    }
                    print("dot")
                default:
                    print("Only supported expression is dot expressions. \(binExp.description) is not yet supported")
                    return ([], true)
                }
                // I can now pull out the binExp processing into a separate function?
            case .identifier(let i):
                if let val = repl.queryVariableMap(variable: i.name) {
                    result_args.append(val.variableValue)
                } else {
                    print("Variable \(i.name) is not in scope.")
                    return ([], true)
                }
            case .literal(let li):
                switch (li.kind) {
                case .literal(let lit):
                    switch (lit) {
                    case .address(let s):
                        result_args.append(s)
                    case .boolean(let bool):
                        result_args.append(bool.rawValue)
                    case .string(let s):
                        result_args.append(s)
                    case .decimal(let decLit):
                        switch (decLit) {
                        case .integer(let i):
                            result_args.append(i.description)
                        case .real(let i1, let i2):
                            result_args.append(i1.description + "." + i2.description)
                        }
                    }
                default:
                    print("ERROR: Found non literal in literal token. Exiting REPL")
                    return ([], true)
                }
                
            default:
                print("This argument type (name: \(a.identifier?.name)  value : \(a.expression.description)) is not supported")
            
                return ([], true)
            }
        }
    
        return (result_args, false)
    }
    

    public func deploy(expr: BinaryExpression, variable_name : String) throws {
        // so from the expression I can extract the assigned expression
        let rhs = expr.rhs

        var args : [String]
        var isError : Bool
        switch (rhs) {
        case .functionCall(let fc):
            let fCallArgs = fc.arguments
            (args, isError) = process_func_call_args(args: fCallArgs)
            if (isError) {
                print("Invalid argument found in constructor function. Failing deployment of  \(variable_name) : \(self.contractName).")
                return
            }
            print(args)
        default:
            print("Invalid expression on rhs of contract insantiation. Failing deployment of \(variable_name) : \(self.contractName).")
            return
        }
        
        return
        

        let fileManager = FileManager.init()
        let path = "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/repl/deploy_contract.js"
        
        if !(fileManager.fileExists(atPath: path)) {
            print("FATAL ERROR: deploy_contract file does not exist, cannot deploy contract for repl. Exiting.")
            exit(0)
        }
        
        let p = Process()
        let pipe = Pipe()
        p.launchPath = "/usr/bin/env"
        p.standardOutput = pipe
        p.currentDirectoryPath = "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/repl"
        p.arguments = ["node", "deploy_contract.js", self.abi, self.bytecode]
        p.launch()
        p.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile();
        if let addr = String(data: data, encoding: .utf8) {
            instanceToAddress[variable_name] = addr
        } else {
            print("ERROR : Could not deploy contract \(self.contractName)")
        }
    }
    
    private func loadContract() {
        do {
            let sourceCode = try String(contentsOf: URL(fileURLWithPath: self.contractFilePath))
            let tokens = try Lexer(sourceFile: URL(fileURLWithPath: self.contractFilePath), isFromStdlib: false, isForServer: true, sourceCode: sourceCode).lex()
            let (_, environment, _) = Parser(tokens: tokens).parse()
            
            let contractFunctions = environment.types[self.contractName]!.allFunctions
            let contractEvents = environment.types[self.contractName]!.allEvents
            
            // process contract event information
            for (eventName, allEventsWithName) in contractEvents {
                // this will always exist if the parse tree has been constructed
                let e = allEventsWithName[0]
                var event_args : [(String, String)] = []
                var count = 0
                let paramTypes = e.eventTypes
                for i in e.parameterIdentifiers {
                    let paramInfo = (i.name, paramTypes[count].name)
                    event_args.append(paramInfo)
                    count += 1
                }
                let contractInfo = ContractEventInfo(name: eventName, event_args: event_args)
                contractEventInfo[eventName] = contractInfo
            }
            
            for (fName, allFuncsWithName) in contractFunctions {
                if (allFuncsWithName.count > 0)
                {
                    isFuncTransaction[fName] = allFuncsWithName[0].isMutating
                    if let resultType = allFuncsWithName[0].declaration.signature.resultType {
                        contractFunctionInfo[fName] = ContractFuncInfo(resultType: resultType.name)
                    }
                    
                    contractFunctionNames.append(fName)
                }
            }
            
            
        } catch {
            print("Fatal error")
            exit(1)
        }
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
            default:
                return nil
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
                jsArgs.append(.Variable(JSVariable(variable: i.name)))
            case .literal(let l):
                if let lit = extract_literal(literalToken: l) {
                    jsArgs.append(lit)
                }
            case .binaryExpression(let be):
                switch (be.opToken) {
                case .dot:
                    jsArgs.append(process_dot_expr(binExpr: be))
                default:
                    break
                }
                
            default:
                break
            }
        }
        
        return jsArgs
    }
    
    private func process_assignment_expr(binExp : BinaryExpression) -> JSNode
    {
        var rhsNode : JSNode? = nil
        var type : Bool? = nil
        var name: String? = nil
        var resultType: String? = nil
        var isInstantiation : Bool = false
        
        
        switch (binExp.lhs) {
        case .variableDeclaration(let vdec):
            name = vdec.identifier.name
            type = vdec.isConstant
            switch (vdec.type.rawType) {
            case .basicType(let rt):
                switch (rt) {
                case .string:
                    resultType = "String"
                case .int:
                    resultType = "Int"
                case .address:
                    resultType = "Address"
                case .bool:
                    resultType = "Bool"
                default:
                    resultType = vdec.type.rawType.name
                }
            default:
                resultType = vdec.type.rawType.name
            }
        default:
            break
        }
        
        
        switch (binExp.rhs) {
        case .binaryExpression(let binExpr):
            switch (binExpr.op.kind) {
            case .punctuation(let p):
                switch (p) {
                case .dot:
                    rhsNode = process_dot_expr(binExpr: binExpr)
                default:
                    break
                }
            default:
                break
            }
        case .functionCall(let fCall):
            isInstantiation = !fCall.identifier.name.lowercased().contains("assert") && !contractFunctionNames.contains(fCall.identifier.name) && fCall.identifier.name.lowercased().contains(self.contractName.lowercased())
            rhsNode = process_func_call(fCall: fCall)
        case .literal(let li):
            if let lit = extract_literal(literalToken: li) {
                rhsNode = lit
            }
        default:
            break
        }
        
        return .VariableAssignment(JSVariableAssignment(lhs: name!, rhs: rhsNode!, isConstant: type!, resultType: resultType!, isInstantiation: isInstantiation))
    }
    
    private func process_dot_expr(binExpr : BinaryExpression) -> JSNode {
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
            rhsNode = process_func_call(fCall: fCall, lhsName: lhsName)
        case .identifier(let i):
            rhsNode = .Variable(JSVariable(variable: i.name))
        default:
            break
        }
        
        return rhsNode!
    }
    
    private func process_func_call(fCall : FunctionCall, lhsName: String = "") -> JSNode {
        let fName : String = fCall.identifier.name
        let funcArgs = process_func_call_args(args: fCall.arguments)
        var isTransaction = false
        
        if let isFuncTransaction = isFuncTransaction[fName] {
            isTransaction = isFuncTransaction
        }
        
        var resultType: String = ""
        if let funcInfo = contractFunctionInfo[fName] {
            resultType = funcInfo.getType()
        }
        
        var contractEventInfo : ContractEventInfo? = nil
        if fName.contains("assertEventFired") {
            if let eventInfo = self.contractEventInfo[funcArgs[0].description] {
                contractEventInfo = eventInfo
            } else {
                print("The event " + funcArgs[0].description + " does not exist")
                exit(0)
            }
        }
        
        let isAssert = fName.lowercased().contains("assert")
        
        return .FunctionCall(JSFunctionCall(contractCall: contractFunctionNames.contains(fName), transactionMethod: isTransaction, isAssert: isAssert, functionName: fName, contractName: lhsName, args: funcArgs, resultType: resultType, eventInformation: contractEventInfo))
    }
    
    
    public func process_expr(expr : Expression) -> JSNode
    {
        var jsNode : JSNode? = nil
        switch (expr) {
        case .binaryExpression(let binExp):
            switch (binExp.op.kind) {
            case .punctuation(let punc):
                switch (punc) {
                case .equal:
                    jsNode = process_assignment_expr(binExp: binExp)
                case .dot:
                    jsNode = process_dot_expr(binExpr: binExp)
                default:
                    break
                }
            default: break
            }
        case .functionCall(let fCall):
            jsNode = process_func_call(fCall: fCall)
        default:
            break
        }
        
        return jsNode!
    }

    
    
    
    
}