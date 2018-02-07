var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function(accounts) {
  it("should be possible write to a dictionary", async function() {
    const instance = await Contract.deployed()
    let t;

    await instance.write(0x20, 20);
    await instance.write(0x21, 25);

    t = await instance.get.call(0x20);
    assert.equal(t.valueOf(), 20);

    t = await instance.get.call(0x21);
    assert.equal(t.valueOf(), 25);
  });

  it("should be possible write to the first dictionary", async function() {
    const instance = await Contract.deployed()
    let t;

    await instance.write(0x20, 20);
    await instance.write(0x21, 25);

    t = await instance.get.call(0x20);
    assert.equal(t.valueOf(), 20);

    t = await instance.get.call(0x21);
    assert.equal(t.valueOf(), 25);
  });

  it("should be possible write to the second dictionary", async function() {
    const instance = await Contract.deployed()
    let t;

    await instance.write2(0x50, 10);
    await instance.write2(0x51, 12);

    t = await instance.get2.call(0x50);
    assert.equal(t.valueOf(), 10);

    t = await instance.get2.call(0x51);
    assert.equal(t.valueOf(), 12);
  });
});
