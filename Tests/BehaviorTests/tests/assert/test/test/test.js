// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function(accounts) {
  it("should crash on assertion failures", async function() {
    const instance = await Contract.deployed();

    try {
      await instance.shouldCrash.call();
    } catch (e) {
      return
    }

    assert.fail();
  });

  it("should not crash on assertion success", async function() {
    const instance = await Contract.deployed();

    await instance.shouldNotCrash.call();
  });

  it("should crash if value is sent to non-payable function", async function() {
      const instance = await Contract.deployed();

      try {
        await instance.shouldNotCrash({from: accounts[0], value: 10});
      } catch (e) {
        return
      }

      assert.fail();
  });
});
