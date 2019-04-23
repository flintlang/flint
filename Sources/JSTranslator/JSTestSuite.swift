import AST
import Parser
import Lexer
import Foundation

public class JSTestSuite {
    // for now lets write this to support a single test contract
    private var contractName: String
    private var filePath: String
    private var testSuiteName: String
    private let ast : TopLevelModule
    private var JSTestFuncs: [JSTestFunction]
    
    private var isFuncTransaction : [String:Bool]
    private var contractFunctionNames : [String]
    private var contractFunctionInfo : [String : ContractFuncInfo]
    
    private let firstHalf : String =
"""
const Web3 = require('web3');
const fs = require('fs');
const path = require('path');
const solc = require('solc');
const chalk = require('chalk');
const web3 = new Web3();
const eth = web3.eth;
web3.setProvider(new web3.providers.HttpProvider('http://localhost:8545'));

const defaultAcc = web3.personal.newAccount("1");
web3.personal.unlockAccount(defaultAcc, "1", 1000);
web3.eth.defaultAccount = defaultAcc;

function setAddr(addr) {
    web3.personal.unlockAccount(addr, "1", 1000);
    web3.eth.defaultAccount = addr;
}

function unsetAddr() {
    web3.personal.unlockAccount(defaultAcc, "1", 1000);
    web3.eth.defaultAccount = defaultAcc;
}

async function deploy_contract(abi, bytecode) {
    let gasEstimate = eth.estimateGas({data: bytecode});
    let localContract = eth.contract(JSON.parse(abi));

    return new Promise (function(resolve, reject) {
    localContract.new({
      from:defaultAcc,
      data:bytecode,
      gas:gasEstimate}, function(err, contract){
       if(!err) {
          // NOTE: The callback will fire twice!
          // Once the contract has the transactionHash property set and once its deployed on an address.
           // e.g. check tx hash on the first call (transaction send)
          if(!contract.address) {
          //console.log(contract.transactionHash) // The hash of the transaction, which deploys the contract
         
          // check address on the second call (contract deployed)
          } else {
              //newContract = myContract;
              //contractDeployed = true;
              // setting the global instance to this contract
              resolve(contract);
          }
           // Note that the returned "myContractReturned" === "myContract",
          // so the returned "myContractReturned" object will also get the address set.
       }
     });
    });
}

async function check_tx_mined(tx_hash) {
    let txs = eth.getBlock("latest").transactions;
    return new Promise(function(resolve, reject) {
        while (!txs.includes(tx_hash)) {
            txs = eth.getBlock("latest").transactions;
        }
        resolve("true");
    });
}

async function transactional_method(contract, methodName, args) {
    var tx_hash = await new Promise(function(resolve, reject) {
        contract[methodName]['sendTransaction'](...args, function(err, result) {
            resolve(result);
        });
    });

    let isMined = await check_tx_mined(tx_hash);

    return new Promise(function(resolve, reject) {
        resolve(tx_hash);
    });
}

function call_method_string(contract, methodName, args) {
    return contract[methodName]['call'](...args);
}

function call_method_int(contract, methodName, args) {
    return contract[methodName]['call'](...args).toNumber();
}

function assertEqual(result_dict, expected, actual) {
    let result = expected === actual;
    result_dict['result'] = result && result_dict['result'];

    if (result && result_dict['result']) {
        result_dict['msg'] = "has Passed";
    } else {
        result_dict['msg'] = "has Failed";
    }

    return result_dict
}

async function isRevert(result_dict, fncName, args, t_contract) {
    let tx_hash = await transactional_method(t_contract, fncName, args);
    let receipt = eth.getTransactionReceipt(tx_hash);
    let result = (receipt.status === "0x0");
    return result
}

async function assertCallerUnsat(result_dict, fncName, args, t_contract) {
    let result = await isRevert(result_dict, fncName, args, t_contract);

    result_dict['result'] = result && result_dict['result'];

    if (result && result_dict['result']) {
            result_dict['msg'] = "has Passed";
    } else {
           result_dict['msg'] = "has Failed";
    }
}

async function assertCallerSat(result_dict, fncName, args, t_contract) {
    let result = await isRevert(result_dict, fncName, args, t_contract);
    result = !result

    result_dict['result'] = result && result_dict['result'];

    if (result && result_dict['result']) {
            result_dict['msg'] = "has Passed";
    } else {
           result_dict['msg'] = "has Failed";
    }
}

async function assertCanCallInThisState(result_dict, fncName, args, t_contract) {
    await assertCallerSat(result_dict, fncName, args, t_contract)
}

async function assertCantCallInThisState(result_dict, fncName, args, t_contract) {
    await assertCallerUnsat(result_dict, fncName, args, t_contract)
}

function newAddress() {
    let newAcc = web3.personal.newAccount("1");
    web3.personal.unlockAccount(newAcc, "1", 1000);
    return newAcc;
}

function process_test_result(res, test_name) {
    if (res['result'])
    {
        console.log(chalk.green(test_name + " " + res['msg']));
    } else {
        console.log(chalk.red(test_name + " " +  res['msg']));
    }
}

"""

    // creates the JSTestSuite class
    public init(ast: TopLevelModule) {
        self.contractName = ""
        self.filePath = ""
        self.testSuiteName = ""
        self.JSTestFuncs = []
        self.isFuncTransaction = [:]
        self.contractFunctionNames = []
        self.contractFunctionInfo = [:]
        self.ast = ast
        loadTestContractVars()
    }
    
    public func getFilePathToFlintContract() -> String {
        return self.filePath
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
            
            for (fName, allFuncsWithName) in contractFunctions {
                if (allFuncsWithName.count > 0)
                {
                    isFuncTransaction[fName] = allFuncsWithName[0].isMutating
                    if let resultType = allFuncsWithName[0].declaration.signature.resultType {
                        contractFunctionInfo[fName] = ContractFuncInfo(type: resultType.name)
                    }
    
                    contractFunctionNames.append(fName)
                }
            }
            
        } catch {
            print("Fatal error")
            exit(1)
        }
    }
    
    private func processContractBehaviour(contractBehaviour: ContractBehaviorDeclaration)
    {
        
        let members : [ContractBehaviorMember] = contractBehaviour.members
        
        // process each of the function declarations
        for m in members {
            switch (m) {
            case .functionDeclaration(let fdec):
                if let fnc = processContractFunction(fdec: fdec) {
                    JSTestFuncs.append(fnc)
                }
            default:
                continue
            }
        }
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
                jsStmts.append(process_expr(expr: expr))
            default:
                continue
            }
        }
        
        return JSTestFunction(name: fName, stmts: jsStmts)
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
        
        let isAssert = fName.lowercased().contains("assert")
        
        return .FunctionCall(JSFunctionCall(contractCall: contractFunctionNames.contains(fName), transactionMethod: isTransaction, isAssert: isAssert, functionName: fName, contractName: lhsName, args: funcArgs, resultType: resultType))
    }
    
    
    private func process_expr(expr : Expression) -> JSNode
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
        
        fnc += "    let abi = compiledContract.contracts[':_Interface' + nameOfContract].interface; \n"
        
        fnc += "    let bytecode = \"0x\" + compiledContract.contracts[':' + nameOfContract].bytecode; \n"
        
        var counter: Int = 0
        for tFnc in JSTestFuncs {
            fnc += "    let depContract_\(counter) = await deploy_contract(abi, bytecode); \n"
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
