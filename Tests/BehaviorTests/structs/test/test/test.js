var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function(accounts) {
  it("assign basic values", async function() {
    const instance = await Contract.deployed();
    let t;

    await instance.setAx(40);
    await instance.setAy(41);
    await instance.setBxx(42);
    await instance.setBxx2(430);
    await instance.setBxy(43);
    await instance.setBy(44);

    t = await instance.getAx();
    assert.equal(t.valueOf(), 40);

    t = await instance.getAy();
    assert.equal(t.valueOf(), 41);

    t = await instance.getBxx();
    assert.equal(t.valueOf(), 42);

    t = await instance.getBxx2();
    assert.equal(t.valueOf(), 430);

    t = await instance.getBxy();
    assert.equal(t.valueOf(), 43);

    t = await instance.getBy();
    assert.equal(t.valueOf(), 44);
  });

  
  it("assign to dynamic data types", async function() {
    const instance = await Contract.deployed();
    let t;

    for (let i = 0; i < 50; i++) {
      await instance.append(50 + i);
    }

    for (let i = 0; i < 50; i++) {
      t = await instance.get(i);
      assert.equal(t.valueOf(), 50 + i);
    }

    t = await instance.getSize();
    assert.equal(t.valueOf(), 50);

    await instance.append(205);

    t = await instance.get(t.toNumber() + 1);
    assert.equal(t.valueOf(), 205);
  });
});

