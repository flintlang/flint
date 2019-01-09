// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

var ExternalContract = artifacts.require("./Emitter.sol");

contract(config.contractName, function(accounts) {
  it("should correctly call external contract", async function() {
    const externalContract = await ExternalContract.deployed();

    const instance = await Contract.deployed();


    let t = await instance.callExternal(externalContract.address);
    assert.equal(t.valueOf(), 7);
  });
});

