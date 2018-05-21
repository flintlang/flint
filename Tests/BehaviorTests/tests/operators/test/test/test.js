// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function(accounts) {
  it("should be possible to perform <", async function() {
    const instance = await Contract.deployed();

    let t = await instance.lessThan(5, 4);
    assert.equal(t.valueOf(), 0);

    t = await instance.lessThan(1, 2);
    assert.equal(t.valueOf(), 1);
  });

  it("should be possible to perform <=", async function() {
    const instance = await Contract.deployed();

    let t = await instance.lessThanOrEqual(5, 4);
    assert.equal(t.valueOf(), 0);

    t = await instance.lessThanOrEqual(2, 2);
    assert.equal(t.valueOf(), 1);
  });

  it("should be possible to perform >", async function() {
    const instance = await Contract.deployed();

    let t = await instance.greaterThan(5, 5);
    assert.equal(t.valueOf(), 0);

    t = await instance.greaterThan(2, 1);
    assert.equal(t.valueOf(), 1);
  });

  it("should be possible to perform >=", async function() {
    const instance = await Contract.deployed();

    let t =await instance.greaterThanOrEqual(5, 5);
    assert.equal(t.valueOf(), 1);

    t = await instance.greaterThanOrEqual(1, 2);
    assert.equal(t.valueOf(), 0);
  });

  it("should be possible to perform +", async function() {
    const instance = await Contract.deployed();

    const t = await instance.plus(5, 4);
    assert.equal(t.valueOf(), 9);
  });

  it("should be possible to perform -", async function() {
    const instance = await Contract.deployed();

    const t = await instance.minus(5, 4);
    assert.equal(t.valueOf(), 1);
  });

  it("should be possible to perform *", async function() {
    const instance = await Contract.deployed();

    const t = await instance.times(5, 4);
    assert.equal(t.valueOf(), 20);
  });

  it("should be possible to perform /", async function() {
    const instance = await Contract.deployed();

    const t = await instance.divide(20, 4);
    assert.equal(t.valueOf(), 5);
  });

  it("should be possible to perform ==", async function() {
    const instance = await Contract.deployed();

    let t = await instance.equal(20, 20);
    assert.equal(t.valueOf(), 1);

    t = await instance.equal(20, 21);
    assert.equal(t.valueOf(), 0);
  });

  it("should be possible to perform !=", async function() {
    const instance = await Contract.deployed();

    let t = await instance.notEqual(20, 20);
    assert.equal(t.valueOf(), 0);

    t = await instance.notEqual(20, 21);
    assert.equal(t.valueOf(), 1);
  });

  it("should be possible to perform ||", async function() {
    const instance = await Contract.deployed();

    let t = await instance.orOp(0, 1);
    assert.equal(t.valueOf(), 1);

    t = await instance.orOp(0, 0);
    assert.equal(t.valueOf(), 0);
  });

  it("should be possible to perform &&", async function() {
    const instance = await Contract.deployed();

    let t = await instance.andOp(0, 1);
    assert.equal(t.valueOf(), 0);

    t = await instance.andOp(1, 1);
    assert.equal(t.valueOf(), 1);
  });
});


contract(config.contractName, function(accounts) {
  it("should crash on + overflow", async function() {
    const instance = await Contract.deployed();

    const maxInt = web3.toBigNumber(2).pow(256).sub(1);

    try {
      await instance.plus(maxInt, 1);
    } catch(e) {
      return;
    }

    assert.fail()
  });

  it("should crash on - overflow", async function() {
    const instance = await Contract.deployed();

    try {
      await instance.minus(0, 1);
    } catch(e) {
      return;
    }

    assert.fail()
  });

  it("should crash on * overflow", async function() {
    const instance = await Contract.deployed();

    const maxInt = web3.toBigNumber(2).pow(256);

    try {
      await instance.times(maxInt.div(2), maxInt.div(2));
    } catch(e) {
      return;
    }

    assert.fail()
  });

  it("should crash on / by 0", async function() {
    const instance = await Contract.deployed();

    try {
      await instance.divide(2, 0);
    } catch(e) {
      return;
    }

    assert.fail()
  });
});

contract(config.contractName, function(accounts) {
  it("should support overflowing +", async function() {
    const instance = await Contract.deployed();
    let t;

    const maxInt = web3.toBigNumber(2).pow(256).sub(1);

    t = await instance.overflowingPlus(maxInt, 1);
    assert.equal(t.valueOf(), 0);

    t = await instance.overflowingPlus(maxInt, 40);
    assert.equal(t.valueOf(), 39);
  });

  it("should support overflowing -", async function() {
    const instance = await Contract.deployed();

    const maxInt = web3.toBigNumber(2).pow(256).sub(1);

    const t = await instance.overflowingMinus(0, 1);
    assert.equal(t.valueOf(), maxInt);
  });

  it("should support overflowing *", async function() {
    const instance = await Contract.deployed();

    const maxInt = web3.toBigNumber(2).pow(256);

    const t = await instance.overflowingTimes(maxInt.div(2), maxInt.div(2));
    assert.equal(t.valueOf(), 0);
  });
});
