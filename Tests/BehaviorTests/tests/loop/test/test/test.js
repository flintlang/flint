// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function(accounts) {
  it("should read the sum of values it writes to the first array", async function() {
    const instance = await Contract.deployed()
    let t;

    await instance.write(0, 4);
    await instance.write(1, 3);
    await instance.write(2, 4590);
    await instance.write(3, 304);

    t = await instance.sum.call();
    assert.equal(t.valueOf(), 4901);

    await instance.write(2, 40);

    t = await instance.sum.call();
    await assert.equal(t.valueOf(), 351)
    });

  it("should read the sum of values it writes to the second array", async function() {
    const instance = await Contract.deployed();
    let t;

    await instance.write2(0, 40);
    await instance.write2(1, 48);
    await instance.write2(9, 12);

    t = await instance.sum2.call();
    assert.equal(t.valueOf(), 100);
    });

  it("should correctly return sumBoth", async function() {
    const instance = await Contract.deployed();
    let t;

    await instance.write(0, 1);
    await instance.write2(0, 4);
    await instance.write(2, 20);
    await instance.write2(2, 80);
    await instance.write(3, 100);
    await instance.write2(3, 400);

    t = await instance.sumBoth.call();
    assert.equal(t.valueOf(), 668);
    });

  it("should correctly return sum3", async function() {
    const instance = await Contract.deployed();
    let t;

    t = await instance.sum3.call();
    assert.equal(t.valueOf(), 55);
    });

  it("should correctly return sum4", async function() {
    const instance = await Contract.deployed();
    let t;

    t = await instance.sum4.call();
    assert.equal(t.valueOf(), 60);
    });

  it("should correctly return sum5", async function() {
    const instance = await Contract.deployed();
    let t;

    t = await instance.sum5.call();
    assert.equal(t.valueOf(), 55);
    });

  it("should correctly return sum6", async function() {
    const instance = await Contract.deployed();
    let t;

    t = await instance.sum6.call();
    assert.equal(t.valueOf(), 10);
    });

  it("should correctly return sum7", async function() {
    const instance = await Contract.deployed();
    let t;

    await instance.write3(0, 1);
    t = await instance.value3(0);
    assert.equal(t.valueOf(), 1);

    await instance.write3(1, 4);
    t = await instance.value3(1);
    assert.equal(t.valueOf(), 4);

    await instance.write3(2, 20);
    t = await instance.value3(2);
    assert.equal(t.valueOf(), 20);

    await instance.write3(3, 80);
    t = await instance.value3(3);
    assert.equal(t.valueOf(), 80);

    t = await instance.sum7.call();
    assert.equal(t.valueOf(), 105);
    });

  it("should correctly return sum8", async function() {
    const instance = await Contract.deployed();
    let t;

    t = await instance.sum8.call();
    assert.equal(t.valueOf(), 4);
    });

  it("should revert on out-of-bounds array accesses", async function() {
    const instance = await Contract.deployed();
    let t;

    try {
    await instance.write2(10, 40);
    } catch (e) {
    return
    }

    assert.fail()
    });

  it("should correctly return sum9", async function() {
    const instance = await Contract.deployed();
    let t;

    await instance.writeNested(0, 0, 1);
    t = await instance.valueNested(0, 0);
    assert.equal(t.valueOf(), 1);

    await instance.writeNested(0, 1, 1);
    t = await instance.valueNested(0, 1);
    assert.equal(t.valueOf(), 1);

    await instance.writeNested(1, 0, 1);
    t = await instance.valueNested(1, 0);
    assert.equal(t.valueOf(), 1);

    await instance.writeNested(1, 1, 1);
    t = await instance.valueNested(1, 1);
    assert.equal(t.valueOf(), 1);

    await instance.writeNested(1, 2, 1);
    t = await instance.valueNested(1, 2);
    assert.equal(t.valueOf(), 1);

    t = await instance.sum9.call();
    assert.equal(t.valueOf(), 5);
  });

  it("should correctly loop over dictionaries", async function() {
    const instance = await Contract.deployed();
    let t;

    await instance.writeDict(0, 1);
    t = await instance.valueDict(0);
    assert.equal(t.valueOf(), 1);

    await instance.writeDict(10, 2);
    t = await instance.valueDict(10);
    assert.equal(t.valueOf(), 2);

    await instance.writeDict(20, 3);
    t = await instance.valueDict(20);
    assert.equal(t.valueOf(), 3);

    t = await instance.sum10.call();
    assert.equal(t.valueOf(), 6);

    t = await instance.sum11.call();
    assert.equal(t.valueOf(), 3);
  });

});
