// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function(accounts) {
  it("should be able to register to the bank", async function() {
    const instance = await Contract.deployed();
    let t;

    await instance.register({from: accounts[0]});
    await instance.register({from: accounts[1]});

    t = await instance.getBalance.call({from: accounts[0]});
    assert.equal(t.valueOf(), 0);
  });

  it("should be possible to deposit money", async function() {
    const instance = await Contract.deployed();
    let t;

    await instance.deposit({from: accounts[0], value: 20});
    t = await instance.getBalance.call({from: accounts[0]});
    await instance.register({from: accounts[0]});
    assert.equal(t.valueOf(), 20);

    await instance.deposit({from: accounts[0], value: 30});
    t = await instance.getBalance.call({from: accounts[0]});
    assert.equal(t.valueOf(), 50);

    t = await instance.getBalance.call({from: accounts[1]});
    assert.equal(t.valueOf(), 0);

    await instance.deposit({from: accounts[1], value: 18});
    t = await instance.getBalance.call({from: accounts[1]});
    assert.equal(t.valueOf(), 18);
  });

  it("should not possible to deposit money if the account is not registered", async function() {
    const instance = await Contract.deployed();

    try {
      await instance.deposit({from: accounts[2], value: 20});
    } catch (e) {
      return;
    }

    assert.fail();
  });

  it("it should be possible to transfer money from one account to another", async function() {
    const instance = await Contract.deployed();
    let t;

    t = await instance.getBalance.call({from: accounts[0]});
    const previousBalance0 = t.toNumber();

    t = await instance.getBalance.call({from: accounts[1]});
    const previousBalance1 = t.toNumber();

    await instance.transfer(5, accounts[1], {from: accounts[0]});

    t = await instance.getBalance.call({from: accounts[0]});
    assert.equal(t.valueOf(), previousBalance0 - 5);

    t = await instance.getBalance.call({from: accounts[1]});
    assert.equal(t.valueOf(), previousBalance1 + 5);
  });

  it("should not be possible to call manager functions from an account", async function() {
    const instance = await Contract.deployed();
    let t;

    try {
      await instance.clear(accounts[1], {from: accounts[0]});
    } catch (e) {
      return;
    }

    assert.fail();
  });

  it("should be possible for the manager to clear an account", async function() {
    const instance = await Contract.deployed();
    let t;

    await instance.clear(accounts[0], {from: accounts[9]});
    t = await instance.getBalance.call({from: accounts[0]});
    assert.equal(t.valueOf(), 0);
  });

  it("should be possible to withdraw money", async function() {
    const instance = await Contract.deployed();
    let t;

    const oldBalance = web3.eth.getBalance(accounts[3]);

    const registerTxInfo = await instance.register({from: accounts[3]});
    const registerTx = await web3.eth.getTransaction(registerTxInfo.tx);
    const registerGasCost = registerTx.gasPrice.mul(registerTxInfo.receipt.gasUsed);

    const depositTxInfo = await instance.deposit({from: accounts[3], value: web3.toWei(10, 'ether')});
    const depositTx = await web3.eth.getTransaction(depositTxInfo.tx);
    const depositGasCost = depositTx.gasPrice.mul(depositTxInfo.receipt.gasUsed);

    t = await instance.getBalance.call({from: accounts[3]});
    assert.equal(t.valueOf(), web3.toWei(10, 'ether'));

    const withdrawTxInfo = await instance.withdraw(web3.toWei(4, 'ether'), {from: accounts[3]});
    const withdrawTx = await web3.eth.getTransaction(withdrawTxInfo.tx);
    const withdrawGasCost = withdrawTx.gasPrice.mul(withdrawTxInfo.receipt.gasUsed);

    t = await instance.getBalance.call({from: accounts[3]});
    assert.equal(t.valueOf(), web3.toWei(6, 'ether'));

    const newBalance = web3.eth.getBalance(accounts[3]);

    assert.equal(newBalance.valueOf(), oldBalance.sub(web3.toWei(6, 'ether')).sub(registerGasCost).sub(depositGasCost).sub(withdrawGasCost).valueOf());
  })

  it("should not be possible to withdraw too much money", async function() {
    const instance = await Contract.deployed();
    let t;

    const oldBalance = web3.eth.getBalance(accounts[4]);

    const registerTxInfo = await instance.register({from: accounts[4]});
    const registerTx = await web3.eth.getTransaction(registerTxInfo.tx);
    const registerGasCost = registerTx.gasPrice.mul(registerTxInfo.receipt.gasUsed);

    const depositTxInfo = await instance.deposit({from: accounts[4], value: web3.toWei(10, 'ether')});
    const depositTx = await web3.eth.getTransaction(depositTxInfo.tx);
    const depositGasCost = depositTx.gasPrice.mul(depositTxInfo.receipt.gasUsed);

    t = await instance.getBalance.call({from: accounts[4]});
    assert.equal(t.valueOf(), 10000000000000000000);

    try {
      const withdrawTxInfo = await instance.withdraw(web3.toWei(20, 'ether'), {from: accounts[4]});
    } catch (e) {
      t = await instance.getBalance.call({from: accounts[4]});
      assert.equal(t.valueOf(), web3.toWei(10, 'ether'));

      const newBalance = web3.eth.getBalance(accounts[4]);

      // Estimate
      const withdrawGasCost = registerGasCost / 2

      assert.isTrue(newBalance.lessThan(oldBalance.sub(web3.toWei(10, 'ether')).sub(registerGasCost).sub(depositGasCost).sub(withdrawGasCost)));
      return
    }

    assert.fail();
  })
});
