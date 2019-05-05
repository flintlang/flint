// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function(accounts) {
  it("should be possible to store a string", async function() {
    const instance = await Contract.deployed();

    await instance.set("hello");
    const t = await instance.get();

    assert.equal(web3.toUtf8(t.valueOf()), "hello");
  });

  it("should be possible to compare strings", async function() {
    const instance = await Contract.deployed();

    await instance.set("hello");

    let t = await instance.isEqual("hello");
    assert.equal(t.valueOf(), 1);

    t = await instance.isEqual("hell");
    assert.equal(t.valueOf(), 0);

    t = await instance.isNotEqual("hello");
    assert.equal(t.valueOf(), 0);

    t = await instance.isNotEqual("hell");
    assert.equal(t.valueOf(), 1);
  });
});


