const Web3 = require('web3');
const fs = require('fs');
const path = require('path');
const web3 = new Web3();
const eth = web3.eth;
web3.setProvider(new web3.providers.HttpProvider('http://localhost:8545'));

const defaultAcc = web3.personal.newAccount("1");
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

async function transactional_method_string(contract, methodName, args) {
    var value = ((web3.toAscii(contract[methodName]['call'](...args))).replace(/\0/g, '')).trim();
    var tx_hash = await transactional_method(contract, methodName, args);

    return {tx_hash: tx_hash, rVal: value};
}

async function transactional_method_int(contract, methodName, args) {
    var value = contract[methodName]['call'](...args).toNumber();
    var tx_hash = await transactional_method(contract, methodName, args);

    return {tx_hash: tx_hash, rVal: value};
}

async function main() {
	/* SET UP OF CONTRACT, LINK TO APPROPRIATE ADDRESS ON THE BLOCKCHAIN*/
	let abi = process.argv[2];
	let address  = process.argv[3].trim();
        let localContract = eth.contract(JSON.parse(abi));
	address = "" + address + "";
	let instance = localContract.at(address);	

	/* CALL CONTRACT METHOD  */
	let functionNameToBeExecuted = process.argv[4];
	let isTransaction = process.argv[5];
	let resType  = process.argv[6];
	let args = process.argv[7];
	var json_args = []
	if (!(args === "")) {
	    json_args = JSON.parse(args); 
	}

	var res = "";

	if (isTransaction) {

	   if (resType === "Int") {
		   let resObj = await transactional_method_int(instance, functionNameToBeExecuted, json_args) 
		   res = resObj.rVal
	   } else if (resType === "String") {
		   let resObj = await transactional_method_string(instance, functionNameToBeExecuted, json_args) 
		   res = resObj.rVal
	   } else if (resType === "Address") {
		   let resObj = await transactional_method_string(instance, functionNameToBeExecuted, json_args) 
		   res = resObj.rVal
	   } else {

		   let tx_hash = await transactional_method(instance, functionNameToBeExecuted, json_args) 
		   res = tx_hash
	   }

	} else {

	   if (resType === "Int") {
		   res = call_method_int(instance, functionNameToBeExecuted, json_args);
	   } else if (resType === "String") {
		   res = call_method_string(instance, functionNameToBeExecuted, json_args);
	   } else if (resType === "Address") {
		   res = call_method_string(instance, functionNameToBeExecuted, json_args);
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

