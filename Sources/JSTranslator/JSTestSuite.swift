import AST
import Parser
import Lexer
import Foundation

public class JSTestSuite {
    // for now lets write this to support a single test contract
    private var contractName: String
    private var filePath: String
    private var testSuiteName: String
    private var JSTestFuncs: [JSTestFunction]
    
    private var isFuncTransaction : [String:Bool]
    private var contractFunctionNames : [String]
    
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

var accountAdd = web3.personal.newAccount("1");
web3.personal.unlockAccount(accountAdd, "1", 1000);
web3.eth.defaultAccount = accountAdd;

async function deploy_contract(abi, bytecode) {
    let gasEstimate = eth.estimateGas({data: bytecode});
    let localContract = eth.contract(JSON.parse(abi));

    return new Promise (function(resolve, reject) {
    localContract.new({
      from:accountAdd,
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
        resolve(isMined);
    });
}

function call_method_int(contract, methodName, args) {
    return contract[methodName]['call'](...args).toNumber();
}

function assertEqual(result_dict, expected, actual) {
    let result = expected === actual;
    result_dict['result'] = result && result_dict['result'];

    // do I want to keep updating the msg
    if (result) {
        result_dict['msg'] = "has Passed";
    } else {
        result_dict['msg'] = "has Failed";
    }

    return result_dict
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
    public init() {
        contractName = ""
        filePath = ""
        testSuiteName = ""
        JSTestFuncs = []
        isFuncTransaction = [:]
        contractFunctionNames = []
    }
    
    // this function is the entry point which takes a flint AST and translates it into a JS AST suitable for testing
    public func convertAST(ast: TopLevelModule) {
        let declarations : [TopLevelDeclaration] = ast.declarations
        
        for d in declarations {
            switch d {
            case .contractDeclaration(let contractDec):
                processContract(contract: contractDec)
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
            let (_, environment, parserDiagnostics) = try Parser(tokens: tokens).parse()
            
            if (environment.syntaxErrors)
            {
                // print syntax errors before exiting and also use throw
                print("failed to compile contract")
                exit(1)
            }
            
            let contractFunctions = environment.types[self.contractName]!.allFunctions
            
            for (fName, allFuncsWithName) in contractFunctions {
                if (allFuncsWithName.count > 0)
                {
                    isFuncTransaction[fName] = allFuncsWithName[0].isMutating
                    contractFunctionNames.append(fName)
                }
            }
            
        } catch {
            print("failed to compile contract")
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
    
    
    private func process_func_call_args(args : [FunctionArgument]) -> [JSNode] {
        
        var jsArgs : [JSNode] = []
        
        for a in args {
            // create a JSNode for each of these but for now we will just do variables
            switch (a.expression)
            {
            case .identifier(let i):
                jsArgs.append(.Variable(JSVariable(variable: i.name)))
            // this should process literals and extract values from literals
            case .literal(let l):
                switch (l.kind) {
                case .literal(let lit):
                    switch (lit) {
                    case .decimal(let dec):
                        switch (dec) {
                        case .integer(let val):
                            jsArgs.append(.Literal(.Integer(val)))
                        default:
                            break
                        }
                    default:
                        break
                    }
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
        
        var isInstantiation : Bool = false
      
        
        switch (binExp.lhs) {
        case .variableDeclaration(let vdec):
            name = vdec.identifier.name
            type = vdec.isConstant
        default:
            break
        }
        
        // we need to do function call
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
            isInstantiation = !fCall.identifier.name.lowercased().contains("assert") && !contractFunctionNames.contains(fCall.identifier.name)
            rhsNode = process_func_call(fCall: fCall)
        default:
            break
        }

    
        return .VariableAssignment(JSVariableAssignment(lhs: name!, rhs: rhsNode!, isConstant: type!, isInstantiation: isInstantiation))
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
        
        let isAssert = fName.lowercased().contains("assert")
        
        return .FunctionCall(JSFunctionCall(contractCall: contractFunctionNames.contains(fName), transactionMethod: isTransaction, isAssert: isAssert, functionName: fName, contractName: lhsName, args: funcArgs))
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
        
        print(file)
    
        return file
    }
}
