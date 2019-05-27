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
          if(!contract.address) {
          } else {
              resolve(contract);
          }
       }
     });
    });
}

function getVal(value, type) {
	if (type === "Int" || type === "Wei") {
		return value.toNumber();
	} else (type == "String" || type == "Address") 
	{
              return ((web3.toAscii(value))).replace(/\0/g, '').trim();
	}
}

async function getEvents(contract, eventName, event_args) {
	return new Promise(function(resolve, reject) {
		let cEvent = contract[eventName](event_args, {fromBlock: 0, toBlock: 'latest'});
		cEvent.get(function(error, logs) {	
			resolve(logs)
		});
	});
}


async function main() {
	let abi = process.argv[2]; 
	let address  = process.argv[3].trim();
	address = "" + address + ""; 
	let eventName = process.argv[4];
	let eventArgNames = JSON.parse(process.argv[5]);
	let eventArgTypes = JSON.parse(process.argv[6]);
        let localContract = eth.contract(JSON.parse(abi));
	let dep_contract = localContract.at(address);

	let logs = await getEvents(dep_contract, eventName, {});

	let evs_for_repl = [];

	logs.forEach(function(entry) {
	      let args = entry.args;
	      let single_event = []
	      eventArgNames.forEach(function(entry) {
		      let type = eventArgTypes[entry];
		      let val = getVal(args[entry], type);
		      single_event.push("(" + entry + ": " + val + ")");
	      });	
	     evs_for_repl.push(single_event.toString());
	});

	let res = "{\n";
	evs_for_repl.forEach(function(entry) {
		res += entry + ", \n";
	});

	res += "}";

	fs.writeFileSync("event_result.txt", res);
} 

main()

