// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

var ExternalContract = artifacts.require("./External.sol");

contract(config.contractName, function() {
  it("should be possible to cast from a lower bit type to a higher bit type", async function() {
    const external = await ExternalContract.deployed();
    const instance = await Contract.deployed();

    let t;
    t = await instance.testReduce(100, external.address);
    assert.equal(t.valueOf(), 100);
  });

  it("should be possible to cast from a higher bit type to a lower bit type for small values", async function() {
    const external = await ExternalContract.deployed();
    const instance = await Contract.deployed();

    let t;
    const value = "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF";
    t = await instance.testIncrease(value, external.address);
    assert.equal(`0x${t.toString(16).toUpperCase()}`, value);
  });

  it("should not be possible to cast from a lower bit type to a higher bit type", async function() {
    const external = await ExternalContract.deployed();
    const instance = await Contract.deployed();
    const value = "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF";

    try {
      await instance.testIncrease(value, external.address);
      assert(false);
    } catch (e) {
      if (e.message == "VM Exception while processing transaction: revert") {
        assert(true);
      } else {
        throw e;
      }
    }
  });

});
