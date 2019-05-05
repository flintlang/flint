// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function(accounts) {
  it("should correctly set initializer arguments for contracts", async function() {
    const instance = await Contract.deployed();
    let t;

    t = await instance.getA();
    assert.equal(t.valueOf(), 4);
    
    t = await instance.getB();
    assert.equal(t.valueOf(), accounts[0]);

    t = await instance.getS();
    assert.equal(web3.toUtf8(t.valueOf()), "hello");

    t = await instance.getS1();
    assert.equal(web3.toUtf8(t.valueOf()), "foo");
  });

  it("should correctly set initializer arguments for structs", async function() {
    const instance = await Contract.deployed();
    let t;

    await instance.setT(10, 1);

    t = await instance.getTx();
    assert.equal(t.valueOf(), 10);
    
    t = await instance.getTy();
    assert.equal(t.valueOf(), 1);

    t = await instance.getTs();
    assert.equal(web3.toUtf8(t.valueOf()), "test");
  });
});


