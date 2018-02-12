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
});


