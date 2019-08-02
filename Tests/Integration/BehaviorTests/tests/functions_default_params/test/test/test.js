// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function() {
  it("should init all to 0", async function() {
    const instance = await Contract.deployed();
    let t;

    t = await instance.getA();
    assert.equal(t.valueOf(), 0);
    t = await instance.getB();
    assert.equal(t.valueOf(), 0);
    t = await instance.getC();
    assert.equal(t.valueOf(), 0);
    t = await instance.getD();
    assert.equal(t.valueOf(), 0);
  });

  it("should should set a: 1, b: 1, c: 10, d: 20", async function() {
    const instance = await Contract.deployed();
    let t;

    t = await instance.test1()
    t = await instance.getA();
    assert.equal(t.valueOf(), 1);
    t = await instance.getB();
    assert.equal(t.valueOf(), 1);
    t = await instance.getC();
    assert.equal(t.valueOf(), 10);
    t = await instance.getD();
    assert.equal(t.valueOf(), 20);
  });

  it("should should set a: 5, b: 10, c: 5, d: 20", async function() {
    const instance = await Contract.deployed();
    let t;

    t = await instance.test2()
    t = await instance.getA();
    assert.equal(t.valueOf(), 5);
    t = await instance.getB();
    assert.equal(t.valueOf(), 10);
    t = await instance.getC();
    assert.equal(t.valueOf(), 5);
    t = await instance.getD();
    assert.equal(t.valueOf(), 20);
  });

  it("should should set a: 7, b: 9, c: 10, d: 66", async function() {
    const instance = await Contract.deployed();
    let t;

    t = await instance.test3()
    t = await instance.getA();
    assert.equal(t.valueOf(), 7);
    t = await instance.getB();
    assert.equal(t.valueOf(), 9);
    t = await instance.getC();
    assert.equal(t.valueOf(), 10);
    t = await instance.getD();
    assert.equal(t.valueOf(), 66);
  });

  it("should should set a: 11, b: 12, c: 7, d: 90", async function() {
    const instance = await Contract.deployed();
    let t;

    t = await instance.test4()
    t = await instance.getA();
    assert.equal(t.valueOf(), 11);
    t = await instance.getB();
    assert.equal(t.valueOf(), 12);
    t = await instance.getC();
    assert.equal(t.valueOf(), 7);
    t = await instance.getD();
    assert.equal(t.valueOf(), 90);
  });

  it("should should set a: 15, b: 15, c: 7, d: 90", async function() {
    const instance = await Contract.deployed();
    let t;

    t = await instance.test5()
    t = await instance.getA();
    assert.equal(t.valueOf(), 15);
    t = await instance.getB();
    assert.equal(t.valueOf(), 15);
    t = await instance.getC();
    assert.equal(t.valueOf(), 7);
    t = await instance.getD();
    assert.equal(t.valueOf(), 90);
  });
});

