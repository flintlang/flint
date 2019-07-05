const Web3 = require('web3');
const fs = require('fs');
const path = require('path');
const web3 = new Web3();
const eth = web3.eth;
web3.setProvider(new web3.providers.HttpProvider('http://localhost:8545'));

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

async function main() {
	let abi = process.argv[2];
	let bytecode  = process.argv[3];
	let constructor_args = JSON.parse(process.argv[4]);
	let dep_contract = await deploy_contract(abi, bytecode);
	if (constructor_args.length > 0) {
            await transactional_method(dep_contract, 'replConstructor', constructor_args)
	}

	console.log(dep_contract.address);
} 

main()

