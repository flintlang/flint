import AST
import Foundation

public class GasEstimator {
    
    private let test_run : Bool
    
    private let jsTemplate : String =
"""
const Web3 = require('web3');
const fs = require('fs');
const path = require('path');
const solc = require('solc');
const web3 = new Web3();
web3.setProvider(new web3.providers.HttpProvider('http://localhost:8545'));

const eth = web3.eth;

const defaultAcc = web3.personal.newAccount("1");
web3.personal.unlockAccount(defaultAcc, "1", 1000);
web3.eth.defaultAccount = defaultAcc;

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

"""
    
    public init(test_run : Bool = false) {
        self.test_run = test_run
    }
    
    public func estimateGas(ast: TopLevelModule, env: Environment) -> String {
        var output : String = ""
        for d in ast.declarations[2...] {
            switch d {
            case .contractDeclaration(let cdec):
               output += getGasEstimate(ast: ast, env: env, contractName: cdec.identifier.name)
               //output += "__CONTRACT__"
            default:
                break
            }
        }
        
        return output
    }
    
    public func processAST(ast : TopLevelModule) -> TopLevelModule {
        var new_decs : [TopLevelDeclaration] = []
        let any_caller_protection : CallerProtection = CallerProtection(identifier: Identifier(name: "any", sourceLocation: .DUMMY))

        var contract_names_to_states : [String : [TypeState]] = [:]
        for dec in ast.declarations {
            switch (dec) {
            case .contractDeclaration(let cdec):
                contract_names_to_states[cdec.identifier.name] = cdec.states
                new_decs.append(.contractDeclaration(cdec))
            case .contractBehaviorDeclaration(let cbDec):
                continue
            default:
                new_decs.append(dec)
            }
        }
        
        for dec in ast.declarations {
            switch (dec) {
            case .contractBehaviorDeclaration(let cbdec):
                let states = contract_names_to_states[cbdec.contractIdentifier.name]!
                new_decs.append(.contractBehaviorDeclaration(ContractBehaviorDeclaration(contractIdentifier: cbdec.contractIdentifier, states: states, callerBinding: cbdec.callerBinding, callerProtections: [any_caller_protection], closeBracketToken: cbdec.closeBracketToken, members: cbdec.members)))
            default:
                continue
            }
        }

        return TopLevelModule(declarations: new_decs)
    }
    
    private func getGasEstimate(ast : TopLevelModule, env : Environment, contractName: String) -> String {
        var jsTestFile : String = ""
        jsTestFile += jsTemplate
        
        let header_estimate_gas =
        """
        async function estimate_gas(pathToContract, nameOfContract) {
            let res_dict = {}
            let source = fs.readFileSync(pathToContract, 'utf8');
            let compiledContract = solc.compile(source, 1);
            let abi = compiledContract.contracts[':_Interface' + nameOfContract].interface;
            let bytecode = "0x" + compiledContract.contracts[':' + nameOfContract].bytecode;
            let c = await deploy_contract(abi, bytecode);
        """
        
        jsTestFile += header_estimate_gas
        jsTestFile += "\n"
        
        jsTestFile += "    res_dict['contract'] = web3.eth.estimateGas({data: bytecode}); \n"
        
        let funcs = env.types[contractName]!.allFunctions
        
        for (fName, _) in funcs {
            jsTestFile += "    res_dict[\"\(fName)\"] = c.\(fName).estimateGas(); \n"
        }
        
        jsTestFile += "    console.log(JSON.stringify(res_dict)); \n} \n"
        
        jsTestFile += "estimate_gas('main.sol', '\(contractName)');"
        
        if test_run {
            return jsTestFile
        }
        
        var jsonOutput = ""
        do {
           jsonOutput = try runNode(jsTestFile: jsTestFile)
        } catch let err {
            print(err)
            print("ERROR : Could not run gas estimator (js file)")
        }
        
        return jsonOutput
    }
    
    func runNode(jsTestFile : String) throws -> String {
        let fileManager = FileManager.init()
        //let outputfile = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: false).appendingPathComponent("utils").appendingPathComponent("gasEstimator").appendingPathComponent("test.js", isDirectory: false)
        //let outputfile = URL(fileURLWithPath: "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/gasEstimator")
        let path = "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/gasEstimator/test.js"
        let outputfile = URL(fileURLWithPath: path)
        
        if !(fileManager.fileExists(atPath: path)) {
            fileManager.createFile(atPath: "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/gasEstimator/test.js", contents: nil)
        }
 
        try jsTestFile.write(to: outputfile, atomically: true, encoding: String.Encoding.utf8)
        
        let p = Process()
        let pipe = Pipe()
        p.launchPath = "/usr/bin/env"
        p.currentDirectoryPath = "/Users/Zubair/Documents/Imperial/Thesis/Code/flint/utils/gasEstimator"
        p.arguments = ["node", "test.js"]
        p.standardOutput = pipe
        p.launch()
        p.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile();
        if let out = String(data: data, encoding: .utf8) {
            return out
        } else {
            return "ERROR : No gas estimates"
        }
    }
}
