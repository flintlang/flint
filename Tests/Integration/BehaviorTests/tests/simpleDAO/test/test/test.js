// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function(accounts) {

  it("shouldn't allow proposals at start", async function() {
    const instance = await Contract.deployed();
    try {
    await instance.newProposal(accounts[0], 40, {from: accounts[3]} );
    } catch (e) {
    return;
    }

    assert.fail();

    });

  it("should only allow 3 accounts", async function() {
    const instance = await Contract.deployed();
     let t;

     t = await instance.slotsLeft()
     assert.equal(t.valueOf(), 3);
     await instance.join(100, {from: accounts[0]});
     t = await instance.slotsLeft()
     assert.equal(t.valueOf(), 2);
     await instance.join(50, {from: accounts[1]});
     t = await instance.slotsLeft()
     assert.equal(t.valueOf(), 1);
     await instance.join(50, {from: accounts[2]});
     t = await instance.slotsLeft()
     assert.equal(t.valueOf(), 0);

      try {
       await instance.join(100, {from: accounts[3]});
      } catch (e) {
      return;
      }

    assert.fail();

    });

  it("should allow proposals after everyone has joined", async function() {
    const instance = await Contract.deployed();
     t = await instance.slotsLeft()
     assert.equal(t.valueOf(), 0);

     try {
     t = await instance.isJoin()
     assert.fail();
     } catch (e) {
     }

    await instance.newProposal(accounts[0], 40, {from: accounts[0]} );
    });

  it("shouldn't allow proposals while one is still in place", async function() {
    const instance = await Contract.deployed();

    try {
     await instance.newProposal(accounts[0], 40, {from: accounts[0]} );
    } catch (e) {
    return;
    }

    assert.fail();

    });

  it("should be possible for accounts to vote after proposed", async function() {
    const instance = await Contract.deployed();

    await instance.vote(1, {from: accounts[0]});
    await instance.vote(0, {from: accounts[1]});
    await instance.vote(1, {from: accounts[2]});
    });

  it("should be possible to execute the proposal after voting", async function() {
    const instance = await Contract.deployed();
    let t;

    await instance.executeProposal({from: accounts[0]} );
    });

  it("should allow proposals again", async function() {
    const instance = await Contract.deployed();

     await instance.newProposal(accounts[0], 40, {from: accounts[1]} );
    });


});
