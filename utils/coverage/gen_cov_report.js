const Web3 = require('web3');
const fs = require('fs');
const path = require('path');
const solc = require('solc');
const web3 = new Web3();
const eth = web3.eth;
web3.setProvider(new web3.providers.HttpProvider('http://localhost:8545'));

const defaultAcc = web3.personal.newAccount("1");
web3.personal.unlockAccount(defaultAcc, "1", 1000);
web3.eth.defaultAccount = defaultAcc;

function getString(hex) {
    return (((web3.toAscii(hex))).replace(/\0/g, '')).trim();
}

async function getEvents(contract, eventName, event_args) {
	return new Promise(function(resolve, reject) {
		let cEvent = contract[eventName](event_args, {fromBlock: 0, toBlock: 'latest'});
		cEvent.get(function(error, logs) {
			resolve(logs)
		});
	});
}

function process_stmc_event_logs(logs) {
	res = []
	logs.forEach(function(entry) {
		let lineNo = entry.args["line"].toNumber();
		res.push("DA:" + lineNo + ",1");
	});

	return res
}

function process_funcC_event_logs(logs) {
	res = []
	logs.forEach(function(entry) {
		let fncName = getString(entry.args["fName"]);
		res.push("FNDA:1," + fncName)
	});

	return res
}

function process_branchC_event_logs(logs) {
	res = []
	logs.forEach(function(entry) {
		let lineNo = entry.args["line"].toNumber();
		let branchNum = entry.args["branch"].toNumber();
		let blockNum = entry.args["blockNum"].toNumber();
		res.push("BRDA:" + lineNo + "," + blockNum + "," + branchNum + "1")
	});

	return res
}

async function main() { 
	let abi = JSON.parse(fs.readFileSync("contract.json").toString())["contracts"][":_InterfaceCounter1"].interface
	let address = "0x986abb64f2d331a63ad47f16a3d59fe8184f0467"
	let localContract = eth.contract(JSON.parse(abi));
	let instance = localContract.at(address);
	let stmt = await getEvents(instance, "stmC", {});
	let fncC = await getEvents(instance, "funcC", {});
	let branchC = await getEvents(instance, "branchC", {});
	let sLogs = process_stmc_event_logs(stmt);	
	let fLogs = process_funcC_event_logs(fncC);	
	let bLogs = process_branchC_event_logs(branchC);	

	let res = sLogs.concat(fLogs).concat(bLogs);
	fs.writeFileSync("coverage.info", "SF: /Users/Zubair/Documents/Imperial/Thesis/Code/flint/test_1.flint \n");
	res.forEach(function(entry) {
		fs.appendFileSync("coverage.info", entry + "\n");
	});

	fs.appendFileSync("coverage.info", "end_of_record");
} 

main()

