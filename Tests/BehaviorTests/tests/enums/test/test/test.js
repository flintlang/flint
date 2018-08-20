// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function(accounts) {
  it("assign values", async function() {
    const instance = await Contract.deployed();
    let t;

    await instance.assignA(1);

    t = await instance.AbCheck();
    assert.equal(t.valueOf(), 1);

    await instance.assignA(0);
     
    t = await instance.AaCheck();
    assert.equal(t.valueOf(), 1);
     
  });
});
contract(config.contractName, function(accounts) {
  it("should have its properties correctly initialized", async function() {
    const instance = await Contract.deployed();
    let t;
     
    t = await instance.AbCheck();
    assert.equal(t.valueOf(), 0);
    t = await instance.AcCheck();
    assert.equal(t.valueOf(), 0);
    t = await instance.AaCheck();
    assert.equal(t.valueOf(), 1);
  });
});

