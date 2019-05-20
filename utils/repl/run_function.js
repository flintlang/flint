const Web3 = require('web3');
const fs = require('fs');
const path = require('path');
const web3 = new Web3();
const eth = web3.eth;
web3.setProvider(new web3.providers.HttpProvider('http://localhost:8545'));

/* CHECK THAT WE ARE ABLE TO FIND SOME ACCOUNTS */
if (eth.accounts.length < 5) {
	fs.writeFileSync("result.txt", "No test net was found, please launch one using flint-block");
	process.exit(0);
}

const defaultAcc = eth.accounts[4];
web3.personal.unlockAccount(defaultAcc, "1", 1000);
web3.eth.defaultAccount = defaultAcc;

function log(data) {
	fs.appendFileSync("log.txt", data + "\n");
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
    let gasEstimate = contract[methodName].estimateGas(...args);  
    let transactionFee = gasEstimate * web3.eth.gasPrice + hyperparam.value;

    var tx_hash;
    if ("value" in hyperparam) {

	    tx_hash = await new Promise(function(resolve, reject) {
		contract[methodName]['sendTransaction'](...args, {value: transactionFee,  gasPrice: web3.eth.gasPrice, gas:gasEstimate}, function(err, result) {
		    if (!err) {
		        resolve(result);
		    } else {
			resolve("ERROR:" + err);
		    }
		});
	    });

    } else {

	    tx_hash = await new Promise(function(resolve, reject) {
		contract[methodName]['sendTransaction'](...args, function(err, result) {
		    if (!err) {
		        resolve(result);
		    } else {
			resolve("ERROR:" + err);
		    }
		});
	    });
    }


    if (!(tx_hash.includes("ERROR"))) {
         let isMined = await check_tx_mined(tx_hash);
    }

    return new Promise(function(resolve, reject) {
        resolve(tx_hash);
    });
}

function isRevert(tx_hash) {
    let receipt = eth.getTransactionReceipt(tx_hash);
    let result = (receipt.status === "0x0");
    return result
}

function call_method_string(contract, methodName, args) {
    return contract[methodName]['call'](...args);
}

function call_method_int(contract, methodName, args) {
    return contract[methodName]['call'](...args).toNumber();
}

async function transactional_method_void(contract, methodName, args, hyperparam) {
    var tx_hash = await transactional_method(contract, methodName, args, hyperparam);
    if (!(tx_hash.includes("ERROR"))) {
	    let isReverted = isRevert(tx_hash);
	    if (isReverted) {
		    tx_hash = "reverted transaction";
	    }
    }
      
    return {tx_hash: tx_hash};
}

async function transactional_method_string(contract, methodName, args, hyperparam) {
    var value = ((web3.toAscii(contract[methodName]['call'](...args))).replace(/\0/g, '')).trim();
    var tx_hash = await transactional_method(contract, methodName, args, hyperparam);

    if (!(tx_hash.includes("ERROR"))) 
    {
	    let isReverted = isRevert(tx_hash);
	    if (isReverted) {
		    value = "reverted transaction";
		    tx_hash = "reverted transaction";
	    }
    } else 
    {
	    value = tx_hash
    }
 
    return {tx_hash: tx_hash, rVal: value};
}

async function transactional_method_int(contract, methodName, args, hyperparam) {
    var value = contract[methodName]['call'](...args).toNumber();
    var tx_hash = await transactional_method(contract, methodName, args, hyperparam);
    if (!(tx_hash.includes("ERROR"))) 
    {
	    let isReverted = isRevert(tx_hash);
	    if (isReverted) {
		    value = "reverted transaction";
		    tx_hash = "reverted transaction";
	    }
    } else 
    {
	    value = tx_hash
    }

    return {tx_hash: tx_hash, rVal: value};
}

async function main() {
	/* SET UP OF CONTRACT, LINK TO APPROPRIATE ADDRESS ON THE BLOCKCHAIN*/
	let abi = process.argv[2];
	let address  = process.argv[3].trim();
        let localContract = eth.contract(JSON.parse(abi));
	address = "" + address + "";
	let instance = localContract.at(address);	
	fs.writeFileSync("result.txt", "");

	/* CALL CONTRACT METHOD  */
	let functionNameToBeExecuted = process.argv[4];
	let isTransaction = process.argv[5];
	let resType  = process.argv[6];
	let args = process.argv[7];
	let isPayable = process.argv[8];
	var json_args = []
	if (!(args === "")) {
	    json_args = JSON.parse(args); 
	}

	let hyperparam = {};

	if (isPayable === "true") {
		hyperparam = {value: process.argv[9]};
	}

	var res = "";

	if (isTransaction === "true") {

	   if (resType === "Int") {
		   let resObj = await transactional_method_int(instance, functionNameToBeExecuted, json_args, hyperparam);
		   res = resObj.rVal;
	   } else if (resType === "String") {
		   let resObj = await transactional_method_string(instance, functionNameToBeExecuted, json_args, hyperparam);
		   res = resObj.rVal;
	   } else if (resType === "Address") {
		   let resObj = await transactional_method_string(instance, functionNameToBeExecuted, json_args, hyperparam);
		   res = resObj.rVal;
	   } else {
		   let resObj = await transactional_method_void(instance, functionNameToBeExecuted, json_args, hyperparam);
		   res = resObj.tx_hash; 
	   }

	} else {

	   if (resType === "Int") {
		   res = call_method_int(instance, functionNameToBeExecuted, json_args);
	   } else if (resType === "String") {
		   res = call_method_string(instance, functionNameToBeExecuted, json_args);
	   } else if (resType === "Address") {
		   res = call_method_string(instance, functionNameToBeExecuted, json_args);
           } else if (resType === "nil") {
		   res = "undefined";
	   } else {
		   res = "RETURN TYPE NOT SUPPORTED: " + resType
	   }

	}

	/* RETURN RESULT */
	fs.writeFileSync("result.txt", res)
	process.exit(0)
} 

try {
  main()
} 
catch (error) {
	fs.writeFileSync("error.txt", error);
	process.exit(0);
}

