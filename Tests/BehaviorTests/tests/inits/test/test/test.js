var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function(accounts) {
  it("should correctly set initializer arguments", async function() {
    const instance = await Contract.deployed();
    let t;

    t = await instance.getX();
    assert.equal(t.valueOf(), 4);
    
    t = await instance.getB();
    assert.equal(t.valueOf(), accounts[0]);

    t = await instance.getS();
    assert.equal(web3.toUtf8(t.valueOf()), "hello");
  });
});


