// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function(accounts) {
  it("should have an accessor for a - Address", async function() {
    const instance = await Contract.deployed()
    let t;
    t = await instance.getA();
    assert.equal(t.valueOf(), 0xF480c6298525d6f255849519274722Ef297518C8);
  });
  it("should not have a mutator for a - Address", async function() {
    const instance = await Contract.deployed();
    let t;
    try {
     await instance.setA(0xF480c6298525d6f255849519274722Ef297518C8);
    } catch (e) {
     return;
    }
     assert.fail();
  });
});
contract(config.contractName, function(accounts) {
  it("should have a mutator for b - Bool", async function() {
    const instance = await Contract.deployed();
    let t;
    await instance.setB(1);
  });
  it("should have a mutator for i - Int", async function() {
    const instance = await Contract.deployed();
    let t;
    await instance.setI(42);
  });
  it("should have an accessor for b - Bool", async function() {
    const instance = await Contract.deployed();
    let t;
    t = await instance.getB();
    assert.equal(t.valueOf(), 1);
  });
  it("should have an accessor for i - Int", async function() {
    const instance = await Contract.deployed();
    let t;
    t = await instance.getI();
    assert.equal(t.valueOf(), 42);
  });
});
contract(config.contractName, function(accounts) {
  it("should have a mutator for arr - Int[4]", async function() {
    const instance = await Contract.deployed();
    let t;
    await instance.setArr(1, 32);
    });
  it("should have a mutator for dict - [Int : Address]", async function() {
    const instance = await Contract.deployed();
    let t;
    await instance.setDict(2, 0xF480c6298525d6f255849519274722Ef297518C8);
    });
  it("should have an accessor for arr - Int[4]", async function() {
    const instance = await Contract.deployed();
    let t;
    t = await instance.getArr(1);
    assert.equal(t.valueOf(), 32);
    });
  it("should have an accessor for dict - [Int : Address]", async function() {
    const instance = await Contract.deployed();
    let t;
    t = await instance.getDict(2);
    assert.equal(t.valueOf(), 0xF480c6298525d6f255849519274722Ef297518C8);
    });

 it("should have an mutator for nested - [[Int]]", async function() {
    const instance = await Contract.deployed();
    let t;
    await instance.setNested(0, 0, 22);
    });
  it("should have an accessor for nested - [[Int]]", async function() {
    const instance = await Contract.deployed();
    let t;
    t = await instance.getNested(0, 0);
    assert.equal(t.valueOf(), 22);
    });
});
