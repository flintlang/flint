const log = require('why-is-node-running')
const Web3 = require('web3');
const fs = require('fs');
const path = require('path');
const solc = require('solc');
const web3 = new Web3();
web3.setProvider(new web3.providers.HttpProvider('http://localhost:8545'));

function compile_contract(pathToContract) {
    let source = fs.readFileSync(pathToContract, 'utf8');
    let compiledContract = solc.compile(source, 1);
    let json = JSON.stringify(compiledContract);
    fs.writeFileSync("contract.json", json);
} 

compile_contract('main.sol');

