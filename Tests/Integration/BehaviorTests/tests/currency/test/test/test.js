// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function(accounts) {
  it("should correctly mint account1", async function() {
    const instance = await Contract.deployed();
    let t;

    await instance.mint(0, 20);

    t = await instance.get(0);
    assert.equal(t.valueOf(), 20);

    t = await instance.get(1);
    assert.equal(t.valueOf(), 0);
  });

  it("should transfer funds from account1 to account2", async function() {
    const instance = await Contract.deployed();
    let t;

    await instance.transfer1(0, 1, 5);

    t = await instance.get(0);
    assert.equal(t.valueOf(), 15);

    t = await instance.get(1);
    assert.equal(t.valueOf(), 5);
  });
  
  it("should transfer funds from account2 to account1", async function() {
    const instance = await Contract.deployed();
    let t;

    await instance.transfer2(1, 0, 2);

    t = await instance.get(0);
    assert.equal(t.valueOf(), 17);

    t = await instance.get(1);
    assert.equal(t.valueOf(), 3);
  });
});


