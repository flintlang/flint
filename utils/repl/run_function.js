const Web3 = require('web3');
const fs = require('fs');
const path = require('path');
const web3 = new Web3();
const eth = web3.eth;
web3.setProvider(new web3.providers.HttpProvider('http://localhost:8545'));

const defaultAcc = web3.personal.newAccount("1");
web3.personal.unlockAccount(defaultAcc, "1", 1000);
web3.eth.defaultAccount = defaultAcc;

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

function log(data) {
	fs.appendFileSync("log.txt", data + "\n");
}

async function main() {
	/* SET UP OF CONTRACT, LINK TO APPROPRIATE ADDRESS ON THE BLOCKCHAIN*/
	let abi = process.argv[2];
	let address  = process.argv[3].trim();
        let localContract = eth.contract(JSON.parse(abi));
	address = "" + address + "";
	let instance = localContract.at(address);	

	/* CALL CONTRACT METHOD (NOT IMPLEMENTED YET) */
        let x = call_method_int(instance, 'getValue', []);

	/* RETURN RESULT */
	console.log(x);
} 

main()

