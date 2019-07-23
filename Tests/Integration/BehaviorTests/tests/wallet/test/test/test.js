// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function(accounts) {
  it("should be possible to deploy the counter", async function() {
    await Contract.new();
  });
  it("should be possible to increase the balance", async function() {
    let wallet = await Contract.new();
    await wallet.deposit({value: 10, from: accounts[0]});
    let balance = await wallet.getBalance();
    assert.equal(balance.valueOf(), 10);
  });
  it("should have a zero value initially", async function() {
    let counter = await Contract.new();
    let value = await counter.getNumDeposits();
    assert.equal(value.valueOf(), 0);
  });
  it("should be possible to interact with the counter", async function() {
    let counter = await Contract.new();
    var value;

    value = await counter.getNumDeposits();
    assert.equal(value.valueOf(), 0);

    await counter.deposit({value: 10});

    value = await counter.getNumDeposits();
    assert.equal(value.valueOf(), 1);

    value = await counter.getNumDeposits();
    assert.equal(value.valueOf(), 1);

    await counter.deposit({value: 10});

    value = await counter.getNumDeposits();
    assert.equal(value.valueOf(), 2);

    await counter.deposit({value: 10});

    await counter.deposit({value: 10});

    value = await counter.getNumDeposits();
    assert.equal(value.valueOf(), 4);
  });
});
