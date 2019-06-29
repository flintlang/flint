import JSTranslator
import AST
import Parser
import Lexer
import Diagnostic
import Foundation
import Rainbow
import SwiftyJSON

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
    
    public func getContractName() -> String {
        return contractName
    }
    
    public func getResultType(fnc : String) -> String {
        return contractFunctionInfo[fnc]!.getType()
    }
    
    private func extract_wei_argument(args: [FunctionArgument]) -> (Int, [FunctionArgument])? {
        if args.count > 0 {
            let wei_arg = args[0]
            
            guard let param_name = wei_arg.identifier else {
                print("Function is payable but no wei was sent, please send wei using the _wei parameter, _wei should be the first parameter".lightRed.bold)
                return nil
            }
            
            if param_name.name != "_wei" {
                print("Function is payable but no wei was sent, please send wei using the _wei parameter, _wei should be the first parameter".lightRed.bold)
                return nil
            }
            
            switch (wei_arg.expression) {
            case .literal(let li):
                switch (li.kind) {
                case .literal(let lit):
                    switch (lit) {
                    case .decimal(let dec):
                        switch (dec) {
                        case .integer(let i):
                            return (i, Array(args[1...]))
                        default:
                            print("Invalid type found for Wei value".lightRed.bold)
                        }
                    default:
                        print("Invalid type found for Wei value".lightRed.bold)
                    }
                default:
                    print("Invalid type found for Wei value".lightRed.bold)
                }
            default:
                print("Invalid type found for Wei value".lightRed.bold)
            }
        }
        
        return nil
    }

    public func run(fCall : FunctionCall, instance : String, expr : Expression? = nil) -> String? {
        guard let addr = instanceToAddress[instance] else {
            print("\(instance) is not in scope.".lightRed.bold)
            return nil
        }
        
        guard let funcInfo = contractFunctionInfo[fCall.identifier.name] else {
            print("Function : \(fCall.identifier.name) was not found in contract \(self.contractName)".lightRed.bold)
            return nil
        }
        
        var func_args : [FunctionArgument] = fCall.arguments
        var wei_value : Int? = nil
        if contractFunctionInfo[fCall.identifier.name]!.isPayable() {
            guard let (weiVal, remainingArgs) = extract_wei_argument(args: func_args) else {
                return nil
            }
            func_args = remainingArgs
            wei_value = weiVal
        }
        
        guard let fArgs = process_func_call_args(args: func_args) else {
            print("Failed to run function \(fCall.identifier.name) as arguments were malformed".lightRed.bold)
            return nil
        }
        
        guard let args_data = try? JSONSerialization.data(withJSONObject: fArgs, options: []) else {
            print("Failed to process arguments for \(fCall.identifier.name)".lightRed.bold)
            return nil
        }
        
        guard let args = String(data: args_data, encoding: .utf8) else {
            print("Failed to process arguments for \(fCall.identifier.name)".lightRed.bold)
            return nil
        }
        
        guard let isTransaction = isFuncTransaction[fCall.identifier.name] else {
            print("Function : \(fCall.identifier.name) was not found in contract \(self.contractName)".lightRed.bold)
            return nil
        }
        
        let resType = funcInfo.getType()
        
        let fileManager = FileManager.init()
        let path = "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/repl/run_function.js"
        
        if !(fileManager.fileExists(atPath: path)) {
            print("FATAL ERROR: run_function file does not exist, cannot deploy contract for repl. Exiting.".lightRed.bold)
            exit(0)
        }
        
        var node_args = ["node", "run_function.js", self.abi, addr, fCall.identifier.name, isTransaction.description, resType, args, false.description]
        
        if let weiVal = wei_value {
            node_args = ["node", "run_function.js", self.abi, addr.trimmingCharacters(in: .whitespacesAndNewlines), fCall.identifier.name, isTransaction.description, resType, args, true.description, weiVal.description]
        }
        
        let p = Process()
        let pipe = Pipe()
        p.launchPath = "/usr/bin/env"
        p.standardOutput = pipe
        p.currentDirectoryPath = "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/repl"
        p.arguments = node_args
        p.launch()
        p.waitUntilExit()
        
        let result_file_path = "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/repl/result.txt"
        
        guard let result = try? String(contentsOf: URL(fileURLWithPath: result_file_path)) else {
            print("Could not extract result of function \(fCall.identifier.name)".lightRed.bold)
            return nil
        }
        
        return result
    }
    
    private func process_func_call_args(args : [FunctionArgument]) -> [String]? {
    
        var result_args : [String] = []
        
        for a in args {
            guard let _ = a.identifier else {
              print("Missing labels to argument for function call, missing for expr: \(a.expression)".lightRed.bold)
              return nil
            }
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
                                    if let result = rContract.run(fCall: fc, instance: rVar.variableName) {
                                        result_args.append(result)
                                    } else {
                                        print("Was not able to run \(fc.description)".lightRed.bold)
                                        return nil
                                    }
                                default:
                                    print("Only function calls on rhs of dot expressions are currently supported".lightRed.bold)
                                    return nil
                                }
                            }
                            
                        } else {
                            print("Variable \(i.name) is not in scope.".lightRed.bold)
                            return nil
                        }
                    default:
                        print("Identfier not found on lhs of dot expression".lightRed.bold)
                        return nil
                    }
                default:
                    print("Only supported expression is dot expressions. \(binExp.description) is not yet supported".lightRed.bold)
                    return nil
                }
                
            case .identifier(let i):
                if let val = repl.queryVariableMap(variable: i.name) {
                    result_args.append(val.variableValue)
                } else {
                    print("Variable \(i.name) is not in scope.".lightRed.bold)
                    return nil
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
                    print("ERROR: Found non literal in literal token. Exiting REPL".lightRed.bold)
                    return nil
                }
                
            default:
                print("This argument type (name: \(a.identifier!.name)  value : \(a.expression.description)) is not supported".lightRed.bold)
            
                return nil
            }
        }
    
        return result_args
    }
    

    public func deploy(expr: BinaryExpression, variable_name : String) throws -> String? {
        let rhs = expr.rhs
        var args : [String]
        switch (rhs) {
        case .functionCall(let fc):
            
            if fc.identifier.name != self.contractName {
                print("Mismatch of contract types \(fc.identifier.name) != \(self.contractName)".lightRed.bold)
                return "ERROR"
            }
            
            let fCallArgs = fc.arguments
            if let function_args = process_func_call_args(args: fCallArgs) {
                args = function_args
            } else {
                print("Invalid argument found in constructor function. Failing deployment of  \(variable_name) : \(self.contractName).".lightRed.bold)
                return nil
            }
        default:
            print("Invalid expression on rhs of contract insantiation. Failing deployment of \(variable_name) : \(self.contractName).".lightRed.bold)
            return nil
        }
        
        
        let json_args = JSON(args)
        
        guard let rawString = json_args.rawString() else {
            print("Could not extract JSON constructor arguments".lightRed.bold)
            return nil
        }
        
        let fileManager = FileManager.init()
        let path = "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/repl/deploy_contract.js"
        
        if !(fileManager.fileExists(atPath: path)) {
            print("FATAL ERROR: deploy_contract file does not exist, cannot deploy contract for repl. Exiting.".lightRed.bold)
            exit(0)
        }
        
        print("Deploying \(variable_name) : \(self.contractName)".lightGreen)
        
        let p = Process()
        let pipe = Pipe()
        p.launchPath = "/usr/bin/env"
        p.standardOutput = pipe
        p.currentDirectoryPath = "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/repl"
        p.arguments = ["node", "deploy_contract.js", self.abi, self.bytecode, rawString]
        p.launch()
        p.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile();
        if let addr = String(data: data, encoding: .utf8) {
            instanceToAddress[variable_name] = addr
            print("Contract deployed at address: ".lightGreen + addr.trimmingCharacters(in: .whitespacesAndNewlines).lightWhite)
            return addr
        } else {
            print("ERROR : Could not deploy contract \(self.contractName)".lightRed.bold)
            return nil
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
                    isFuncTransaction[fName] = allFuncsWithName[0].isMutating || allFuncsWithName[0].declaration.isPayable
                    
                    var resultTypeVal = "nil"
                    if let resultType = allFuncsWithName[0].declaration.signature.resultType {
                        resultTypeVal = resultType.name
                    }
                    
                    contractFunctionInfo[fName] = ContractFuncInfo(resultType: resultTypeVal, payable: allFuncsWithName[0].declaration.isPayable)
                    contractFunctionNames.append(fName)
                }
            }
        } catch {
            print("Fatal error")
            exit(1)
        }
    }
    
}
