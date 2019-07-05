
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
async function estimate_gas(pathToContract, nameOfContract) {
    let res_dict = {}
    let source = fs.readFileSync(pathToContract, 'utf8');
    let compiledContract = solc.compile(source, 1);
    let abi = compiledContract.contracts[':_Interface' + nameOfContract].interface;
    let bytecode = "0x" + compiledContract.contracts[':' + nameOfContract].bytecode;
    let c = await deploy_contract(abi, bytecode);
    res_dict['contract'] = web3.eth.estimateGas({data: bytecode}); 
    res_dict["getValue"] = c.getValue.estimateGas(); 
    res_dict["increment"] = c.increment.estimateGas(); 
    res_dict["changeS2"] = c.changeS2.estimateGas(); 
    res_dict["increment1"] = c.increment1.estimateGas(); 
    console.log(JSON.stringify(res_dict)); 
} 
estimate_gas('main.sol', 'Counter');
