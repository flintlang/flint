const Web3 = require('web3');
const fs = require('fs');
const path = require('path');
const web3 = new Web3();
const eth = web3.eth;
web3.setProvider(new web3.providers.HttpProvider('http://localhost:8545'));


fs.writeFileSync("gen_addr.txt", "");

let addr = web3.personal.newAccount("");
web3.personal.unlockAccount(addr, "", 1000);

fs.writeFileSync("gen_addr.txt", addr);
