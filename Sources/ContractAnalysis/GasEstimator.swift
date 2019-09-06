import AST
import Foundation
import Utils

public class GasEstimator {

  private let isTestRun: Bool

  private let jsTemplate: String =
      """
      const Web3 = require('web3');
      const fs = require('fs');
      const path = require('path');
      const solc = require('solc');
      const web3 = new Web3();
      web3.setProvider(new web3.providers.HttpProvider('http://localhost:8545'));

      const eth = web3.eth;

      const defaultAcc = "\(Configuration.ethereumAddress)";
      web3.personal.unlockAccount(defaultAcc, "", 1000);
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
             } else {
               console.log(err);
               process.exit();
             }
           });
          });
      }

      """

  public init(isTestRun: Bool = false) {
    self.isTestRun = isTestRun
  }

  public func estimateGas(ast: TopLevelModule, environment: Environment) -> String {
    var output: String = ""
    ast.declarations[2...].forEach { (declaration: TopLevelDeclaration) in
      if case .contractDeclaration(let contractDeclaration) = declaration {
        output.append(getGasEstimate(ast: ast,
                                     environment: environment,
                                     contractName: contractDeclaration.identifier.name))
      }
    }

    return output
  }

  public func processAST(ast: TopLevelModule) -> TopLevelModule {
    var newDeclarations: [TopLevelDeclaration] = []
    let anyCallerProtection: CallerProtection = CallerProtection(
        identifier: Identifier(name: "any", sourceLocation: .DUMMY))

    var contractNamesToStates: [String: [TypeState]] = [:]
    for declaration in ast.declarations {
      switch declaration {
      case .contractDeclaration(let contractDeclaration):
        contractNamesToStates[contractDeclaration.identifier.name] = contractDeclaration.states
        newDeclarations.append(.contractDeclaration(contractDeclaration))
      case .contractBehaviorDeclaration:
        continue
      default:
        newDeclarations.append(declaration)
      }
    }

    for declaration in ast.declarations {
      switch declaration {
      case .contractBehaviorDeclaration(let contractBehaviorDeclaration):
        let states = contractNamesToStates[contractBehaviorDeclaration.contractIdentifier.name]!
        newDeclarations.append(.contractBehaviorDeclaration(
            ContractBehaviorDeclaration(contractIdentifier: contractBehaviorDeclaration.contractIdentifier,
                                        states: states,
                                        callerBinding: contractBehaviorDeclaration.callerBinding,
                                        callerProtections: [anyCallerProtection],
                                        closeBracketToken: contractBehaviorDeclaration.closeBracketToken,
                                        members: contractBehaviorDeclaration.members)))
      default:
        continue
      }
    }

    return TopLevelModule(declarations: newDeclarations)
  }

  private func getGasEstimate(ast: TopLevelModule, environment: Environment, contractName: String) -> String {
    var jsTestFile: String = ""
    jsTestFile += jsTemplate

    let headerEstimateGas =
        """
        async function estimate_gas(pathToContract, nameOfContract) {
            let res_dict = {}
            let source = fs.readFileSync(pathToContract, 'utf8');
            let compiledContract = solc.compile(source, 1);
            let abi = compiledContract.contracts[':_Interface' + nameOfContract].interface;
            let bytecode = "0x" + compiledContract.contracts[':' + nameOfContract].bytecode;
            let c = await deploy_contract(abi, bytecode);
        """

    jsTestFile += headerEstimateGas
    jsTestFile += "\n"

    jsTestFile += "    res_dict['contract'] = web3.eth.estimateGas({data: bytecode}); \n"

    let functions = environment.types[contractName]!.allFunctions

    for (functionName, functionData) in functions {
      let explicitParameters = functionData[0].declaration.explicitParameters
      if functionData[0].declaration.isPayable {
        continue
      }

      if explicitParameters.count > 0 {
        continue
      }

      jsTestFile += "    res_dict[\"\(functionName)\"] = c.\(functionName).estimateGas(); \n"
    }

    jsTestFile += "    console.log(JSON.stringify(res_dict)); \n} \n"

    jsTestFile += "estimate_gas('main.sol', '\(contractName)');"

    if isTestRun {
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

  func runNode(jsTestFile: String) throws -> String {
    let fileManager = FileManager()
    let file = Path.getFullUrl(path: "utils/gasEstimator/test.js")
    if !(fileManager.fileExists(atPath: file.path)) {
      fileManager.createFile(atPath: file.path, contents: nil)
    }

    try jsTestFile.write(to: file, atomically: true, encoding: String.Encoding.utf8)
    let processResult: ProcessResult = Process.run(executableURL: Configuration.nodeLocation,
                                                   arguments: ["test.js"],
                                                   currentDirectoryURL: Path.getFullUrl(path: "utils/gasEstimator"))
    return processResult.standardOutputResult ?? "ERROR: No gas estimates"
  }
}
