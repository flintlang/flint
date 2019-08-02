// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function(accounts) {
  it("compute factorial of 5", async () => {
    const instance = await Contract.deployed()
    await instance.calculate(5)
    const t = await instance.getValue.call();
    assert.equal(t.valueOf(), 120);
  });

  it("compute factorial of 1", async () => {
    const instance = await Contract.deployed()
    await instance.calculate(1)
    const t = await instance.getValue.call();
    assert.equal(t.valueOf(), 1);
  });
});
