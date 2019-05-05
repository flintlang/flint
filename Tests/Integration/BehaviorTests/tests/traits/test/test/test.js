// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function(accounts) {
  it("allow trait functions to be called", async function() {
      const instance = await Contract.deployed()
      let t;

      t = await instance.foo.call();
      assert.equal(t.valueOf(), 0);

      await instance.setFoo(3);
      t = await instance.foo.call();
      assert.equal(t.valueOf(), 3);

      t = await instance.bar.call();
      assert.equal(t.valueOf(), false);

  });
});
