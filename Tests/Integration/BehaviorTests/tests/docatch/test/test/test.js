// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

var ExternalContract = artifacts.require("./Returner.sol");

contract(config.contractName, function(accounts) {
  it("should correctly call an external contract", async function() {
    const externalContract = await ExternalContract.deployed();
    const instance = await Contract.deployed();

    const result = await instance.test1(externalContract.address);

    assert.equal(result.valueOf(), 7);
  });

  it("should not catch in do catch without errors", async function() {
    const externalContract = await ExternalContract.deployed();
    const instance = await Contract.deployed();

    const result = await instance.test2(externalContract.address);

    assert.equal(result.valueOf(), 49);
  });

  it("should catch in do catch when errors occur", async function() {
    const externalContract = await ExternalContract.deployed();
    const instance = await Contract.deployed();

    const result = await instance.test3(externalContract.address);

    assert.equal(result.valueOf(), 99);
  });
});
