const fs = require('fs');
const solc = require('solc');

function compile_contract(pathToContract) {
    let source = fs.readFileSync(pathToContract, 'utf8');
    let compiledContract = solc.compile(source, 1);
    let json = JSON.stringify(compiledContract);
    fs.writeFileSync("contract.json", json);
} 

compile_contract('main.sol');

