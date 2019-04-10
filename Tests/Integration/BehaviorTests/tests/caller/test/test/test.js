// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function(accounts) {
 it("should be possible for the owner to add another owner", async function() {
    const instance = await Contract.deployed();
    let t;

    await instance.addOwner(accounts[0], {from: accounts[9]});
    t = await instance.getOwner(0, {from: accounts[0]});
    assert.equal(t.valueOf(), accounts[9]);
    t = await instance.getOwner(1, {from: accounts[9]});
    assert.equal(t.valueOf(), accounts[0]);
 });

 it("should be possible for the original owner to access all ifYouCan functions", async function() {
   const instance = await Contract.deployed();
   let t;

   t = await instance.ifYouCan({from: accounts[9]});
   assert.equal(t.valueOf(), 1);

   t = await instance.ifYouCan2({from: accounts[9]});
   assert.equal(t.valueOf(), 1);

   t = await instance.ifYouCan3({from: accounts[9]});
   assert.equal(t.valueOf(), 1);

   t = await instance.ifYouCan4({from: accounts[9]});
   assert.equal(t.valueOf(), 42);

   t = await instance.ifYouCan5({from: accounts[9]});
   assert.equal(t.valueOf(), 42);
 });

 it("should be possible for the original owner to check they can access functions", async function() {
   const instance = await Contract.deployed();
   let t;

   t = await instance.check({from: accounts[9]});
   assert.equal(t.valueOf(), 1);

   t = await instance.check2({from: accounts[9]});
   assert.equal(t.valueOf(), 1);
 });

 it("should be possible for anyone to check that they can't access functions", async function() {
   const instance = await Contract.deployed();
   let t;

   t = await instance.check({from: accounts[1]});
   assert.equal(t.valueOf(), 0);

   t = await instance.check2({from: accounts[1]});
   assert.equal(t.valueOf(), 0);
 });

 it("should be possible for a member of owners to access all functions", async function() {
    const instance = await Contract.deployed();
    let t;

    await instance.addOwner(accounts[0], {from: accounts[9]});

    t = await instance.ifYouCan({from: accounts[0]});
    assert.equal(t.valueOf(), 1);

    t = await instance.ifYouCan2({from: accounts[0]});
    assert.equal(t.valueOf(), 1);

    t = await instance.ifYouCan3({from: accounts[0]});
    assert.equal(t.valueOf(), 1);

    t = await instance.ifYouCan4({from: accounts[0]});
    assert.equal(t.valueOf(), 42);

    t = await instance.ifYouCan5({from: accounts[0]});
    assert.equal(t.valueOf(), 42);

    t = await instance.check({from: accounts[0]});
    assert.equal(t.valueOf(), 1);

    t = await instance.check2({from: accounts[0]});
    assert.equal(t.valueOf(), 1);
    });
});
