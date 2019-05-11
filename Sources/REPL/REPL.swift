import Compiler
import Parser
import AST
import Lexer
import Diagnostic
import Foundation
import JSTranslator
import SwiftyJSON

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
        p.arguments = ["node", "compile_contract.js"]
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
                        print("Could not extract the bytecode for \(nameOfContract). Exiting Repl")
                        exit(0)
                    }
                    
                    guard let abi = json["contracts"][":_Interface" + nameOfContract]["interface"].string else {
                        print("Could not extract the abi for \(nameOfContract)")
                        exit(0)
                    }
                    
                    print("Processing contract: \(nameOfContract)")
                    
                    let rc = REPLContract(contractFilePath: self.contractFilePath, contractName: nameOfContract, abi: abi, bytecode: "0x" + bytecode, repl: self)
                    
                    print("Contract interface: \(abi)")
                    
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
    
    public func run() throws {
        deploy_contracts()
        do {
            print("REPL ACTIVE")
            while var input = readLine() {
                
                guard input != ".exit" else {
                    break
                }
                
                // let c : Counter = Counter()
                // c.increment()
                
                input = "{" + input + "}"
                
                let lex = Lexer(sourceCode: input)
                let tokens = lex.lex()
                let parser = Parser(tokens: tokens)
                let (stmts, diags) = parser.parseRepl()
                
                if stmts.count == 0 {
                    print(try DiagnosticsFormatter(diagnostics: diags, sourceContext: nil).rendered())
                    continue
                }
        
                for stmt in stmts {
                    switch (stmt) {
                    case .expression(let ex):
                        switch (ex) {
                        case .binaryExpression(let binExp):
                
                            if let (rC, variableName) = check_if_instantiation(assignment: binExp) {
                                if let addr = try rC.deploy(expr: binExp, variable_name: variableName) {
                                    variableMap[variableName] = REPLVariable(variableName: variableName, variableType: rC.getContractName(), variableValue: addr)
                                }
                                
                                continue
                            }
                            
                            if let (rC, variableName) = check_if_contract_call(expr: binExp) {
                                switch (binExp.rhs) {
                                case .functionCall(let fCall):
                                    if let res = rC.run(fCall: fCall, instance: variableName) {
                                        print(res)
                                    }
                                default:
                                    print("Not supported yet")
                                }
                                
                                continue
                            }
                            
                            // generic call (this is for all other expressions)
                
                        default:
                            continue
                        }
                    default:
                        print("Syntax is not currently supported")
                    }
                }
            }
            
        } catch let err {
            print(err)
        }
    }
    
    private func check_if_contract_call(expr : BinaryExpression) -> (REPLContract, String)? {
        switch (expr.opToken) {
        case .dot:
            switch (expr.lhs) {
            case .identifier(let i):
                if let rVar = variableMap[i.name] {
                    if let rContract = contractInfoMap[rVar.variableType] {
                        return (rContract, i.name)
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
            print("")
        default:
            return nil
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
        
        if let rContract = self.contractInfoMap[typeName] {
            return (rContract, variableName)
        } else {
            return nil
        }
    }
    
}
