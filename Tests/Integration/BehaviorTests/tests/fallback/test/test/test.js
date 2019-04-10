// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function(accounts) {
  it("should not crash and update variable", async function() {
    const instance = await Contract.deployed();

     await instance.sendTransaction({ value: 1e+18 })
     t = await instance.getCount();
     assert.equal(t.valueOf(), 1);
  });
});


