import AST
import Parser
import Lexer
import Foundation

public class JSTranslator {
    private var contractName: String
    private var filePath: String
    private var testSuiteName: String
    private let ast : TopLevelModule
    private var JSTestFuncs: [JSTestFunction]
    
    public var isFuncTransaction : [String:Bool]
    public var contractFunctionNames : [String]
    public var contractFunctionInfo : [String : ContractFuncInfo]
    public var contractEventInfo : [String : ContractEventInfo]
    public static let callerOrStateFuncs = ["assertCallerSat", "assertCallerUnsat", "assertCanCallInThisState", "assertCantCallInThisState", "assertEventFired", "assertWillThrow"]
    public static let genericAsserts = ["assertEqual"]
    public static let utilityFuncs = ["newAddress", "setAddr", "unsetAddr"]
    public static let allFuncs = JSTranslator.callerOrStateFuncs + JSTranslator.genericAsserts + JSTranslator.utilityFuncs
    
    private let firstHalf : String


    // creates the JSTestSuite class
    public init(ast: TopLevelModule) {
        self.contractName = ""
        self.filePath = ""
        self.testSuiteName = ""
        self.JSTestFuncs = []
        self.isFuncTransaction = [:]
        self.contractFunctionNames = []
        self.contractFunctionInfo = [:]
        self.contractEventInfo = [:]
        let path_to_test_framework = URL(fileURLWithPath: "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/testRunner/test_framework.js")
        self.firstHalf = try! String(contentsOf: path_to_test_framework)
        self.ast = ast
        loadLibraryFuncs()
        loadTestContractVars()
    }
    
    private func loadLibraryFuncs() {
        let assertEqualInfo = ContractFuncInfo(resultType: "nil", payable: false)
        self.contractFunctionInfo["assertEqual"] = assertEqualInfo
        
        let newAddrInfo = ContractFuncInfo(resultType: "Address", payable: false)
        self.contractFunctionInfo["newAddress"] = newAddrInfo
        
        let setAddr =  ContractFuncInfo(resultType: "nil", payable: false)
        self.contractFunctionInfo["setAddr"] = setAddr
        
        let unsetAddr = ContractFuncInfo(resultType: "nil", payable: false)
        self.contractFunctionInfo["unsetAddr"] = unsetAddr

        let assertCallerSat = ContractFuncInfo(resultType: "nil", payable: false)
        self.contractFunctionInfo["assertCallerSat"] = assertCallerSat
        
        let assertCallerUnSat = ContractFuncInfo(resultType: "nil", payable: false)
        self.contractFunctionInfo["assertCallerUnSat"] = assertCallerUnSat
        
        let assertCanCallInThisState = ContractFuncInfo(resultType: "nil", payable: false)
        self.contractFunctionInfo["assertCanCallInThisState"] = assertCanCallInThisState
        
        let assertCantCallInThisState = ContractFuncInfo(resultType: "nil", payable: false)
        self.contractFunctionInfo["assertCantCallInThisState"] = assertCantCallInThisState
        
        let assertWillThrow = ContractFuncInfo(resultType: "nil", payable: false)
        self.contractFunctionInfo["assertWillThrow"] = assertWillThrow
    }
    
    public func getFilePathToFlintContract() -> String {
        return self.filePath
    }
    
    public func getContractName() -> String {
        return self.contractName
    }
    
    public func loadTestContractVars() {
        let declarations : [TopLevelDeclaration] = self.ast.declarations
    
        for d in declarations {
            switch d {
            case .contractDeclaration(let contractDec):
               processContract(contract: contractDec)
            default:
               continue
           }
        }
    
    }
    
    // this function is the entry point which takes a flint AST and translates it into a JS AST suitable for testing
    public func convertAST() {
        let declarations : [TopLevelDeclaration] = self.ast.declarations
        
        for d in declarations {
            switch d {
            case .contractDeclaration:
                loadContract()
            case .contractBehaviorDeclaration(let contractBehaviour):
                processContractBehaviour(contractBehaviour: contractBehaviour)
            default:
                continue
            }
        }
    }
    
    private func loadContract() {
        // process the contract that we actually care about
        do {
            let sourceCode = try String(contentsOf: URL(fileURLWithPath: self.filePath))
            let tokens = try Lexer(sourceFile: URL(fileURLWithPath: self.filePath), isFromStdlib: false, isForServer: true, sourceCode: sourceCode).lex()
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
            print("Fatal error: Loading of contract that is to be tested has failed".lightRed.bold)
            exit(1)
        }
    }
    
    private func processContractBehaviour(contractBehaviour: ContractBehaviorDeclaration)
    {
        
        let members : [ContractBehaviorMember] = contractBehaviour.members
        
        for m in members {
            switch (m) {
            case .functionDeclaration(let fdec):
                //
                let fT = FunctionTranslator(jst: self)
                let (jsFnc, errors) = fT.translate(funcDec: fdec)
                
                if errors.count > 0 {
                    var error = ""
                    for e in errors {
                        error += e.lightRed.bold + "\n\n"
                    }
                    print(error)
                    exit(0)
                }
                
                if let fnc = jsFnc {
                    JSTestFuncs.append(fnc)
                }
                
            default:
                continue
            }
        }
    }
    
    
    private func processContract(contract : ContractDeclaration)
    {
        let members : [ContractMember] = contract.members
        
        for m in members {
            switch (m)
            {
            case .variableDeclaration(let vdec):
                process_contract_vars(vdec: vdec)
            default:
                continue
            }
        }
    }
    
    private func getStringFromExpr(expr : Expression) -> String {
        var fileName : String = ""
        switch (expr) {
        case .literal(let t):
            switch (t.kind) {
            case .literal(let lit):
                switch (lit) {
                case .string(let str):
                    fileName = str
                default:
                    break
                }
            default:
                break
            }
        default:
            break
        }
        
        return fileName
    }
    
    private func process_contract_vars(vdec : VariableDeclaration) {
        let nameOfVar : String = vdec.identifier.name
        
        if (nameOfVar == "filePath") {
            self.filePath = getStringFromExpr(expr: vdec.assignedExpression!)
        } else if (nameOfVar == "contractName") {
            self.contractName = getStringFromExpr(expr: vdec.assignedExpression!)
            
        } else if (nameOfVar == "TestSuiteName") {
            self.testSuiteName = getStringFromExpr(expr: vdec.assignedExpression!)
        }
    }
    
    private func genRunTests() -> String {
        var fnc = "async function run_tests(pathToContract, nameOfContract) {\n"
        
        fnc += "    let source = fs.readFileSync(pathToContract, 'utf8'); \n"
        
        fnc += "    let compiledContract = solc.compile(source, 1); \n"
        
        fnc += "    fs.writeFileSync(\"../coverage/contract.json\", JSON.stringify(compiledContract)); \n"
        
        fnc += "    fs.writeFileSync(\"../coverage/address.txt\", \"\"); \n"
        
        fnc += "    let abi = compiledContract.contracts[':_Interface' + nameOfContract].interface; \n"
        
        fnc += "    let bytecode = \"0x\" + compiledContract.contracts[':' + nameOfContract].bytecode; \n"
        
        var counter: Int = 0
        for tFnc in JSTestFuncs {
            fnc += "    let depContract_\(counter) = await deploy_contract(abi, bytecode); \n"
            fnc += "    fs.appendFileSync(\"../coverage/address.txt\", \"\(tFnc.getFuncName()): \" + depContract_\(counter).address); \n"
            fnc += "    await "  + tFnc.getFuncName() + "(depContract_\(counter)) \n"
            counter += 1
        }
        
        fnc += "}\n\n"
        return fnc
    }
    
    // this is the function that generates the string representation of the JS file -> ready for execution
    public func genFile() -> String {
        var file = firstHalf
        for testFunc in JSTestFuncs {
            file += testFunc.description + "\n"
        }
        
        file += "\n"
        
        file += genRunTests()
        
        file +=
        """
        function  main(pathToContract, nameOfContract) {
            run_tests(pathToContract, nameOfContract)
        } \n\n
        """
    
        file += "main('main.sol', '\(self.contractName)');"
        
        return file
    }
}
