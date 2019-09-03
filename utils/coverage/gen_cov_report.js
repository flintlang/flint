const Web3 = require('web3');
const fs = require('fs');
const path = require('path'); 
const { execSync } = require('child_process') 
const solc = require('solc');
const chalk = require('chalk');
const web3 = new Web3();
const eth = web3.eth;
web3.setProvider(new web3.providers.HttpProvider('http://localhost:8545'));

const defaultAcc = web3.personal.newAccount("");
web3.personal.unlockAccount(defaultAcc, "", 1000);
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
			let curr_count = result_dict["DA"][lineNo];
			if (curr_count === 0) {
				found_counts["DA"] += 1	
			}
			result_dict["DA"][lineNo] += 1;
		} 
	});
}

function process_funcC_event_logs(logs, result_dict, found_counts) {
	logs.forEach(function(entry) {
		let fncName = getString(entry.args["fName"]);
		if (fncName in result_dict["functions"]) {
			let curr_count = result_dict["functions"][fncName];
			if (curr_count === 0) {
				found_counts["functions"] += 1	
			}
			result_dict["functions"][fncName] += 1
		} 
	});
}

function process_branchC_event_logs(logs, result_dict, found_counts) {
	logs.forEach(function(entry) {
		let lineNo = entry.args["line"].toNumber();
		let branchNum = entry.args["branch"].toNumber();
		let blockNum = entry.args["blockNum"].toNumber();
		let curr_count = result_dict["branch"][lineNo].count;
		if (curr_count === 0) {
			found_counts["branch"] += 1	
		}
		if (lineNo in result_dict["branch"]) {
			result_dict["branch"][lineNo].count += 1
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
	let pathToContract = process.argv[3];
	console.log(chalk.yellow("Generating coverage data for " + contractName));
	let abi = JSON.parse(fs.readFileSync("contract.json").toString())["contracts"][":_Interface" + contractName].interface
	let addresses = fs.readFileSync("address.txt").toString().split("\n");

	let res = {};
	let found_counts = {};
	found_counts["functions"] = 0
	found_counts["DA"] = 0
	found_counts["branch"] = 0

	res["functions"] = JSON.parse(fs.readFileSync("function.json").toString());
	res["DA"] = JSON.parse(fs.readFileSync("statements.json").toString());
	res["branch"] = JSON.parse(fs.readFileSync("branch.json").toString());

	var i;
	for (i = 0; i < addresses.length; i++) {
		if (addresses[i] === "") {

		} else {
			let addr = addresses[i].split(":")[1].trim()
			await get_events(abi, addr, res, found_counts);
		}
	}

	let da_records = []
	let branch_records = []
	let fn_records = []
	let fn_name_records = []

	Object.entries(res["functions"]).forEach(function(entry) {
		fn_records.push("FNDA:" + entry[1] + ", " + entry[0])
	});

	Object.entries(res["branch"]).forEach(function(entry) {
		branch_records.push("BRDA:" + entry[1].line + "," + entry[1].blockNum + "," + entry[1].branchNum + "," + entry[1].count);
	});

	Object.entries(res["DA"]).forEach(function(entry) {
		da_records.push("DA:" + entry[0] + "," + entry[1]);
	});

	let function_to_line = JSON.parse(fs.readFileSync("function_to_line.json").toString());


	Object.entries(function_to_line).forEach(function(entry) {
		fn_name_records.push("FN:" + entry[1] + ", " + entry[0]);
	});

	let record_set = da_records.concat(branch_records).concat(fn_records).concat(fn_name_records);;

	let counts = JSON.parse(fs.readFileSync("counts.json").toString());

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

	execSync('rm -rf html/');
	execSync('genhtml --rc lcov_branch_coverage=1 -o html/ coverage.info');
	execSync('open html/index.html');

} 

main()

