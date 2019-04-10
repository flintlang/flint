// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function(accounts) {
  it("allows defaulted functions with self to be called", async function() {
      const instance = await Contract.deployed()
      let t;

      await instance.setFirstBValue(100);
      await instance.setSecondBValue(100);

      t = await instance.add.call();
      assert.equal(t.valueOf(), 200);
  });

  it("allows functions without default implementations with self to be called", async function() {
      const instance = await Contract.deployed()
      let t;

      await instance.setFirstBValue(100);
      await instance.setSecondBValue(100);

      t = await instance.addNoDefault.call();
      assert.equal(t.valueOf(), 200);
  });
});
