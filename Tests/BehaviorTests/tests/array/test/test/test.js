// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function(accounts) {
  it("should return the correct size for fixed size arrays", async function() {
      const instance = await Contract.deployed()
      let t;

      t = await instance.sizeUp.call();
      assert.equal(t.valueOf(), 4);

      t = await instance.sizeUp2.call();
      assert.equal(t.valueOf(), 10);
  });
  it("should return the correct size for empty dynamically sized arrays", async function() {
      const instance = await Contract.deployed()
      let t;

      t = await instance.size3.call();
      assert.equal(t.valueOf(), 0);
  });
  it("should read the value it writes to the first array", async function() {
    const instance = await Contract.deployed()
    let t;

    await instance.write(0, 4);
    await instance.write(1, 3);
    await instance.write(2, 4590);
    await instance.write(3, 304);

    t = await instance.value.call(0);
    assert.equal(t.valueOf(), 4);

    t = await instance.value.call(1);
    assert.equal(t.valueOf(), 3);

    t = await instance.value.call(2);
    assert.equal(t.valueOf(), 4590);

    t = await instance.value.call(3);
    assert.equal(t.valueOf(), 304);

    await instance.write(2, 40);

    t = await instance.value.call(2);
    await assert.equal(t.valueOf(), 40);
  });

  it("should read the value it writes to the second array", async function() {
    const instance = await Contract.deployed();
    let t;

    await instance.write2(0, 40);
    await instance.write2(1, 48);
    await instance.write2(9, 12);

    await instance.write(0, 4);
    await instance.write(1, 5);

    t = await instance.value2.call(1);
    assert.equal(t.valueOf(), 48);

    t = await instance.value2.call(9);
    assert.equal(t.valueOf(), 12);

    t = await instance.value.call(0);
    assert.equal(t.valueOf(), 4);

    t = await instance.value.call(1);
    assert.equal(t.valueOf(), 5);
  });

  it("should correctly return valueBoth", async function() {
    const instance = await Contract.deployed();
    let t;

    await instance.write2(2, 40);
    await instance.write(2, 50);

    t = await instance.valueBoth.call(2);
    assert.equal(t.valueOf(), 90);
  });


  it("should revert on out-of-bounds array accesses", async function() {
    const instance = await Contract.deployed();
    let t;

    try {
      await instance.write2(10, 40);
    } catch (e) {
      try {
        await instance.write3(2, 0, 0, 0);
      } catch (e) {
        return
      }
    }

    assert.fail()
  });

  it("should correctly write to arrays of structs", async function() {
    const instance = await Contract.deployed();
    let t;

    await instance.write3(0, 25, 0, 30);
    await instance.write3(1, 25, 0, 30);
    await instance.write3(0, 12, 1, 31);

    t = await instance.value3a.call(0);
    assert.equal(t.valueOf(), 12);

    t = await instance.value3b.call(0);
    assert.equal(t.valueOf(), 1);

    t = await instance.value3cA.call(0);
    assert.equal(t.valueOf(), 31);

    t = await instance.value3a.call(1);
    assert.equal(t.valueOf(), 25);

    t = await instance.value3b.call(1);
    assert.equal(t.valueOf(), 0);

    t = await instance.value3cA.call(1);
    assert.equal(t.valueOf(), 30);
  });

  it("should return the correct size for non-empty dynamically sized arrays", async function() {
      const instance = await Contract.deployed();
      let t;

      t = await instance.sizeUp3.call();
      assert.equal(t.valueOf(), 2);
  });
<<<<<<< HEAD

  it("should correctly write to nested arrays and dictionaries", async function() {
    const instance = await Contract.deployed();
    let t;

    await instance.nestedSet(0, 0, 1);
    await instance.nestedSet(0, 1, 2);
    await instance.nestedSet(1, 0, 3);
    await instance.nestedSet(0, 1, 4);

    t = await instance.nestedValue.call(0, 0)
    assert.equal(t.valueOf(), 1);
    t = await instance.nestedValue.call(0, 1)
    assert.equal(t.valueOf(), 4);
    t = await instance.nestedValue.call(1, 0)
    assert.equal(t.valueOf(), 3);

    await instance.nestedSet2(0, 0, 1);
    await instance.nestedSet2(0, 1, 2);
    await instance.nestedSet2(1, 0, 3);
    await instance.nestedSet2(0, 1, 4);

    t = await instance.nestedValue2.call(0, 0)
    assert.equal(t.valueOf(), 1);
    t = await instance.nestedValue2.call(0, 1)
    assert.equal(t.valueOf(), 4);
    t = await instance.nestedValue2.call(1, 0)
    assert.equal(t.valueOf(), 3);

    await instance.nestedSet3(0, 0, 0, 1);
    await instance.nestedSet3(0, 0, 1, 5);
    await instance.nestedSet3(0, 1, 0, 2);
    await instance.nestedSet3(1, 0, 0, 3);
    await instance.nestedSet3(0, 1, 0, 4);

    t = await instance.nestedValue3.call(0, 0, 0)
    assert.equal(t.valueOf(), 1);
    t = await instance.nestedValue3.call(0, 0, 1)
    assert.equal(t.valueOf(), 5);
    t = await instance.nestedValue3.call(0, 1, 0)
    assert.equal(t.valueOf(), 4);
    t = await instance.nestedValue3.call(1, 0, 0)
    assert.equal(t.valueOf(), 3);

   await instance.nestedSetDict(0x50, 0, 100);
   await instance.nestedSetDict(0x50, 1, 500);
   await instance.nestedSetDict(0x08, 0, 400);

   t = await instance.nestedValueDict.call(0x50, 0)
   assert.equal(t.valueOf(), 100);
   t = await instance.nestedValueDict.call(0x50, 1)
   assert.equal(t.valueOf(), 500);
   t = await instance.nestedValueDict.call(0x08, 0)
   assert.equal(t.valueOf(), 400);
   });
=======
>>>>>>> Working fixed-size array length provision. Also added tests.
});

contract(config.contractName, function(accounts) {
  it("should correctly return numWrites", async function() {
    const instance = await Contract.deployed();
    let t;

    await instance.write2(2, 40);
    await instance.write(2, 50);

    t = await instance.numWrites.call();
    assert.equal(t.valueOf(), 2);
  });
});
