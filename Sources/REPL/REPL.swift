import Compiler
import Parser
import AST
import Lexer
import Diagnostic
import Foundation
import JSTranslator
import SwiftyJSON
import Rainbow

public class REPL {
    var contractInfoMap : [String : REPLContract] = [:]
    var variableMap : [String : REPLVariable] = [:]
    let contractFilePath : String
    
    public init(contractFilePath: String, contractAddress : String = "") {
        self.contractFilePath = contractFilePath
    }
    
    func getContractData() throws -> String {
        let fileManager = FileManager.init()
        let path = "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/repl/compile_contract.js"
    
        if !(fileManager.fileExists(atPath: path)) {
            print("FATAL ERROR: compile_contract file does not exist, cannot compile contract for repl. Exiting.")
            exit(0)
        }

        let p = Process()
        p.launchPath = "/usr/bin/env"
        p.currentDirectoryPath = "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/repl"
        p.arguments = ["node", "--no-warnings", "compile_contract.js"]
        p.launch()
        p.waitUntilExit()
 
        let contractJsonFilePath = "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/repl/contract.json"
        
        let get_contents_of_json = try String(contentsOf: URL(fileURLWithPath: contractJsonFilePath))
        
        return get_contents_of_json
        
    }
    
    public func queryContractInfo(contractName : String) -> REPLContract? {
        if let rContract = contractInfoMap[contractName] {
            return rContract
        }
        
        return nil
    }
        
    public func queryVariableMap(variable : String) -> REPLVariable? {
        if let rVar = variableMap[variable] {
            return rVar
        }
        
        return nil
    }
    
    private func process_abi_args(args : [[String : String]], payable: Bool = false) -> String {
        var final_args = "("
        
        if payable {
            final_args += "_wei: Wei".lightGreen + ", "
        }
        
        let final_count = args.count
        for (i, a) in args.enumerated() {
            let argName = a["name"]!
            let argType = a["type"]!
            
            var flintType = ""
            if argType == "uint256" {
                flintType = "Int"
            } else if argType == "bytes32" {
                flintType = "String"
            } else if argType == "address" {
                flintType = "Address"
            } else {
                flintType = argType
            }
    
            var flintArg = argName
            flintArg.remove(at: flintArg.startIndex)
            final_args += "\(flintArg) : \(flintType)"
            if (i != final_count - 1) {
                final_args += ", "
            }
       
        }
        
        final_args += ")"
        
        return final_args
    }
    
    private func pretty_print_abi(abi : String) throws {
        
        let abi_array = try JSONSerialization.jsonObject(with: abi.data(using: .utf8)!, options:[]) as? [[String : Any]]
        
        var abi_pretty_funcs : [String] = []
        
        for elem in abi_array! {
            let type = elem["type"]! as! String
            if (type == "function") {
                let payable = elem["payable"]! as! Bool
                var fncName = elem["name"]! as! String
                if fncName == "replConstructor" {
                    fncName = "init".lightBlue
                }
                let inputs = elem["inputs"]! as! [[String : String]]
                let isConstant = elem["constant"] as! Bool
                //let outputs = elem["outputs"] as! [[String : String]]
                let funcSignature = "\(fncName)\(process_abi_args(args: inputs, payable: payable))"
                if isConstant {
                    abi_pretty_funcs.append(funcSignature.lightWhite + " (Constant)".lightCyan.bold)
                } else {
                    if payable {
                        abi_pretty_funcs.append(funcSignature.lightWhite + " (Mutating, Payable)".lightYellow.bold)
                    } else {
                        abi_pretty_funcs.append(funcSignature.lightWhite + " (Mutating)".lightYellow.bold)
                    }
                }
            }
        }
        
        var final_funcs_string = ""
        final_funcs_string += "Contract Functions: \n".lightGreen
        for funcs in abi_pretty_funcs {
            final_funcs_string += funcs + "\n"
        }
        
        print(final_funcs_string)
    }
    
    private func deploy_contracts() {
        let inputFiles = [URL(fileURLWithPath: self.contractFilePath)]
        let outputDirectory = URL(fileURLWithPath: "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/repl")
        let config =  CompilerReplConfiguration(sourceFiles: inputFiles, stdlibFiles: StandardLibrary.default.files, outputDirectory: outputDirectory, diagnostics: DiagnosticPool(shouldVerify: false, quiet: false, sourceContext: SourceContext(sourceFiles: inputFiles)))
  
        do {
            let (ast, environment) = try Compiler.getAST(config: config)
            try Compiler.genSolFile(config: config, ast: ast, env: environment)
            
            let contract_data = try getContractData()
        
            guard let dataFromString = contract_data.data(using: .utf8, allowLossyConversion: false) else {
                print("ERROR : Unable to extract contract information")
                exit(0)
            }
            
            let json = try JSON(data: dataFromString)
            
            for dec in ast.declarations {
                switch (dec) {
                case .contractDeclaration(let cdec):
                    let nameOfContract = cdec.identifier.name
                    
                    guard let bytecode = json["contracts"][":" + nameOfContract]["bytecode"].string else {
                        print("Could not extract the bytecode for \(nameOfContract). Exiting Repl".lightRed.bold)
                        exit(0)
                    }
                    
                    guard let abi = json["contracts"][":_Interface" + nameOfContract]["interface"].string else {
                        print("Could not extract the abi for \(nameOfContract)".lightRed.bold)
                        exit(0)
                    }
                    
                    print("\(nameOfContract): \n".bold.underline.lightWhite)
                    
                    let rc = REPLContract(contractFilePath: self.contractFilePath, contractName: nameOfContract, abi: abi, bytecode: "0x" + bytecode, repl: self)
                    
                    try pretty_print_abi(abi: abi)
                    
                    contractInfoMap[nameOfContract] = rc
                    
                default:
                    continue
                }
        
            }
            
        } catch let err {
            print(err)
            print("Contract file \(self.contractFilePath) was not deployed")
        }
    }
    
    public func addVarToMap(replVar : REPLVariable, name : String) {
        variableMap[name] = replVar
    }
    
    public func run() throws {
        deploy_contracts()
        let replCodeProcessor : REPLCodeProcessor = REPLCodeProcessor(repl: self)
        do {
            print("flint>".lightMagenta, terminator: "")
            while var input = readLine() {
            
                guard input != ".exit" else {
                    break
                }
                
                
                if input == "" {
                    continue
                }
                
                input = "{" + input + "}"
                
                let lex = Lexer(sourceCode: input)
                let tokens = lex.lex()
                let parser = Parser(tokens: tokens)
                let (stmts, diags) = parser.parseRepl()
                
                if stmts.count == 0 {
                    print(try DiagnosticsFormatter(diagnostics: diags, sourceContext: nil).rendered())
                }
        
                for stmt in stmts {
                    switch (stmt) {
                    case .expression(let ex):
                        if let (res, _) = try replCodeProcessor.process_expr(expr: ex) {
                            print(res.trimmingCharacters(in: .whitespacesAndNewlines).lightWhite.bold)
                        }
                    default:
                        print("Syntax is not currently supported".lightRed.bold)
                    }
                }
                
                print("flint>".lightMagenta, terminator: "")
            }
            
        } catch let err {
            print(err)
        }
    }
}
