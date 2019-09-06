
const Web3 = require('web3');
const fs = require('fs');
const path = require('path');
const solc = require('solc');
const chalk = require('chalk');
const web3 = new Web3();
const eth = web3.eth;
web3.setProvider(new web3.providers.HttpProvider('http://localhost:8545'));

const defaultAcc = web3.personal.newAccount("");
web3.personal.unlockAccount(defaultAcc, "", 1000);
web3.eth.defaultAccount = defaultAcc;

function setAddr(addr) {
    web3.personal.unlockAccount(addr, "", 1000);
    web3.eth.defaultAccount = addr;
}

function unsetAddr() {
    web3.personal.unlockAccount(defaultAcc, "", 1000);
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

async function transactional_method_void(contract, methodName, args) {
    var value = contract[methodName]['call'](...args);
    var tx_hash = await transactional_method(contract, methodName, args);

    return {tx_hash: tx_hash, rVal: value};
}

async function transactional_method_string(contract, methodName, args) {
    var value = web3.toAscii(contract[methodName]['call'](...args));
    var tx_hash = await transactional_method(contract, methodName, args);

    return {tx_hash: tx_hash, rVal: value};
}

async function transactional_method_int(contract, methodName, args) {
    var value = contract[methodName]['call'](...args).toNumber();
    var tx_hash = await transactional_method(contract, methodName, args);

    return {tx_hash: tx_hash, rVal: value};
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

async function assertEventFired(result_dict, eventName, event_args, t_contract) {
   let result = await new Promise(function(resolve, reject) {
        let cEvent = t_contract[eventName](event_args, {fromBlock: 0, toBlock: 'latest'});
        cEvent.get(function(error, logs) {
            if (logs.length > 0) {
                resolve(true);
            } else {
                resolve(false);
            }
        });
   });

    result_dict['result'] = result && result_dict['result'];

    if (result && result_dict['result']) {
            result_dict['msg'] = "has Passed";
    } else {
           result_dict['msg'] = "has Failed";
    }
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
    let newAcc = web3.personal.newAccount("");
    web3.personal.unlockAccount(newAcc, "", 1000);
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
async function test_event_fired(t_contract) { 
   let assertResult012 = {result: true, msg:""} 
   console.log(chalk.yellow("Running test_event_fired test")) 
   
   //let c = Counter();;
   let x = await transactional_method_void(t_contract, 'increment', []);
   await assertEventFired(assertResult012, "didComplete", {"val":"1"}, t_contract);
   process_test_result(assertResult012, "test_event_fired")
}

async function run_tests(pathToContract, nameOfContract) {
    let source = fs.readFileSync(pathToContract, 'utf8'); 
    let compiledContract = solc.compile(source, 1); 
    let abi = compiledContract.contracts[':_Interface' + nameOfContract].interface; 
    let bytecode = "0x" + compiledContract.contracts[':' + nameOfContract].bytecode; 
    let depContract_0 = await deploy_contract(abi, bytecode); 
    await test_event_fired(depContract_0) 
}

function  main(pathToContract, nameOfContract) {
    run_tests(pathToContract, nameOfContract)
} 

main('main.sol', 'Counter');
