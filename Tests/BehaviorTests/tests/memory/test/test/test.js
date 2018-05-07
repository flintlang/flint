// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function(accounts) {
  it("should be possible to record information in local structs", async function() {
    const instance = await Contract.deployed()
    let t;

    await instance.setS(1, "hello");

    t = await instance.getSa()
    assert.equal(t.valueOf(), 2);

    t = await instance.getSs()
    assert.equal(web3.toUtf8(t.valueOf()), "hello");
  });

  it("should not override memory of other local structs", async function() {
    const instance = await Contract.deployed()
    let t;

    await instance.setT1(5);

    t = await instance.getTx()
    assert.equal(t.valueOf(), 5);

    await instance.setT2(5);

    t = await instance.getTx()
    assert.equal(t.valueOf(), 6);
  });

  it("support branching", async function() {
    const instance = await Contract.deployed()
    let t;

    await instance.setT3(0, 2, 3);

    t = await instance.getTx()
    assert.equal(t.valueOf(), 4);

    await instance.setT3(1, 2, 3);

    t = await instance.getTx()
    assert.equal(t.valueOf(), 3);
  });
});


