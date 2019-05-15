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

function process_stmc_event_logs(logs, result_dict, found_counts) {

	logs.forEach(function(entry) {
		let lineNo = entry.args["line"].toNumber();
		if (lineNo in result_dict["DA"]) {
			result_dict["DA"][lineNo].count += 1
		} else {
			result_dict["DA"][lineNo] = {lineNo: lineNo, count: 1}
			found_counts.DA += 1
		}
	});
}

function process_funcC_event_logs(logs, result_dict, found_counts) {
	logs.forEach(function(entry) {
		let fncName = getString(entry.args["fName"]);
		if (fncName in result_dict["functions"]) {
			result_dict["functions"][fncName].count += 1
		} else {
			result_dict["functions"][fncName] = {fncName: fncName, count: 1};
			found_counts.functions += 1
		}
	});
}

function process_branchC_event_logs(logs, result_dict, found_counts) {
	logs.forEach(function(entry) {
		let lineNo = entry.args["line"].toNumber();
		let branchNum = entry.args["branch"].toNumber();
		let blockNum = entry.args["blockNum"].toNumber();
		if (lineNo in result_dict["branch"]) {
			result_dict["branch"][lineNo].count += 1
		} else {
			result_dict["branch"][lineNo] = {lineNo: lineNo, blockNum: blockNum, branchNum: branchNum, count: 1}
			found_counts.branch += 1
		}
	});
}

async function get_events(abi, address, result_dict, found_counts) {
	let localContract = eth.contract(JSON.parse(abi));
	let instance = localContract.at(address);
	let stmt = await getEvents(instance, "stmC", {});
	let fncC = await getEvents(instance, "funcC", {});
	let branchC = await getEvents(instance, "branchC", {});
	let sLogs = process_stmc_event_logs(stmt, result_dict, found_counts);	
	let fLogs = process_funcC_event_logs(fncC, result_dict, found_counts);	
	let bLogs = process_branchC_event_logs(branchC, result_dict, found_counts);	
}

async function main() { 
	let contractName = process.argv[2];
	let abi = JSON.parse(fs.readFileSync("contract.json").toString())["contracts"][":_Interface" + contractName].interface
	let addresses = fs.readFileSync("address.txt").toString().split("\n");

	let res = {};
	let found_counts = {};
	found_counts["functions"] = 0
	found_counts["DA"] = 0
	found_counts["branch"] = 0

	res["functions"] = {};
	res["DA"] = {};
	res["branch"] = {};

	var i;
	for (i = 0; i < addresses.length; i++) {
		let addr = addresses[i].split(":")[1].trim()
		await get_events(abi, addr, res, found_counts);
	}

	let da_records = []
	let branch_records = []
	let fn_records = []

	Object.entries(res["functions"]).forEach(function(entry) {
		fn_records.push("FNDA:1, " + entry[1].fncName)
	});

	Object.entries(res["branch"]).forEach(function(entry) {
		branch_records.push("BRDA:" + entry[1].lineNo + "," + entry[1].blockNum + "," + entry[1].branchNum + "," + entry[1].count);
	});

	Object.entries(res["DA"]).forEach(function(entry) {
		da_records.push("DA:" + entry[1].lineNo + "," + entry[1].count);
	});

	let record_set = da_records.concat(branch_records).concat(fn_records);

	let counts = JSON.parse(fs.readFileSync("counts.json").toString());

	let pathToContract = fs.readFileSync("contractFilePath.txt").toString();

        fs.writeFileSync("coverage.info", "SF:" + pathToContract + "\n");

	record_set.forEach(function(entry) {
		fs.appendFileSync("coverage.info", entry + "\n");
	});

	fs.appendFileSync("coverage.info", "BRF:" + counts.branch  + "\n");
	fs.appendFileSync("coverage.info", "BRH:" + found_counts.branch  + "\n");

	fs.appendFileSync("coverage.info", "FNF:" + counts.functions + "\n");
	fs.appendFileSync("coverage.info", "FNH:" + found_counts.functions + "\n");

	fs.appendFileSync("coverage.info", "LF:" + counts.statements + "\n");
	fs.appendFileSync("coverage.info", "LH:" + found_counts.DA  + "\n");

	fs.appendFileSync("coverage.info", "end_of_record");
} 

main()

