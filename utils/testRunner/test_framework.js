const Web3 = require('web3');
const fs = require('fs');
const path = require('path');
const solc = require('solc');
const chalk = require('chalk');
const emoji = require('node-emoji');
const web3 = new Web3();
const eth = web3.eth;
web3.setProvider(new web3.providers.HttpProvider('http://localhost:8545'));

// add checks to see if test net is operating
let defaultAcc;
try {
	defaultAcc = eth.accounts[3];
	web3.personal.unlockAccount(defaultAcc, "1", 1000);
	web3.eth.defaultAccount = defaultAcc;	
} catch(err) {
	console.log(chalk.red("Test accounts could not be located, please run a local geth installation with accounts loaded. Tip: Use flint-block"));
	console.log(err);
	process.exit(0);
}

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
          if(!contract.address) {
              // transaction sent for contract deployment
          } else {
              resolve(contract);
          }
       } else {
	       console.log(err);
	       process.exit(0);
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

async function transactional_method(contract, methodName, args, hyperparam) {
    var tx_hash;
    if ("value" in hyperparam) {
	    let gasEstimate;
	    let transactionFee;
	    try {
		    gasEstimate = contract[methodName].estimateGas(...args);  
		    transactionFee = gasEstimate * web3.eth.gasPrice + hyperparam.value;
	    } catch(err) {
		    console.log(chalk.red("Failed to get gas estimate for: " + methodName + ". This means the function is continously reverting"));
		    console.log(err);
		    process.exit(0);
	    }

	    tx_hash = await new Promise(function(resolve, reject) {
		contract[methodName]['sendTransaction'](...args, {value: transactionFee,  gasPrice: web3.eth.gasPrice, gas:gasEstimate}, function(err, result) {
		    if (!err) {
		        resolve(result);
		    } else {
			console.log(chalk.red("ERROR in transaction, trying to call method: " + methodName + " \n Message from block node:" + err));
			process.exit(0);
		    }
		});
	    });

    } else {

	    tx_hash = await new Promise(function(resolve, reject) {
		contract[methodName]['sendTransaction'](...args, function(err, result) {
		    if (!err) {
		        resolve(result);
		    } else {
			console.log(chalk.red("ERROR in transaction, trying to call method: " + methodName + " \n Message from block node:" + err));
			process.exit(0);
		    }
		});
	    });
    }

    let isMined = await check_tx_mined(tx_hash);

    return new Promise(function(resolve, reject) {
        resolve(tx_hash);
    });
}

async function transactional_method_void(contract, methodName, args, hyperparam) {
    var tx_hash = await transactional_method(contract, methodName, args, hyperparam);
    var value = contract[methodName]['call'](...args);

    return {tx_hash: tx_hash, rVal: value};
}

async function transactional_method_string(contract, methodName, args, hyperparam) {
    var tx_hash = await transactional_method(contract, methodName, args, hyperparam);
    var value = web3.toAscii(contract[methodName]['call'](...args));

    return {tx_hash: tx_hash, rVal: value};
}

async function transactional_method_int(contract, methodName, args, hyperparam) {
    var tx_hash = await transactional_method(contract, methodName, args, hyperparam);
    var value = contract[methodName]['call'](...args).toNumber();

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
    let tx_hash = await transactional_method(t_contract, fncName, args, {});
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

function produce_pass_msg(name) {
    let len = name.length;
    let passed_length = "passed".length;

    let spaces_to_add = len - passed_length;
    let passed_msg = "passed "
    if (spaces_to_add > 0) {
        passed_msg = new Array(spaces_to_add - 2).join(' ') + passed_msg
    }

    console.log(chalk.magentaBright.bold(name));
    console.log(chalk.greenBright.bold(passed_msg) + emoji.get('white_check_mark'));
    
}

function produce_fail_msg(name) {
    let len = name.length;
    let failed_length = "failed".length;

    let spaces_to_add = len - failed_length;
    let failed_msg = "failed "
    if (spaces_to_add > 0) {
        failed_msg = new Array(spaces_to_add - 2).join(' ') + failed_msg
    }

    console.log(chalk.magentaBright.bold(name));
    console.log(chalk.red.bold(failed_msg) + emoji.get('x'));
    
}

function process_test_result(res, test_name) {
    if (res['result'])
    {
        produce_pass_msg(test_name)
    } else {
        produce_fail_msg(test_name)
    }
}

