// RUN: cd %S && truffle test

var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var Interface = artifacts.require("./_Interface" + config.contractName + ".sol");
Contract.abi = Interface.abi

contract(config.contractName, function() {
  it("should emit A(a: 1, b: 3)", async function() {
    var meta;

    await Contract.deployed().then(function (instance) {
      meta = instance;
      return meta.test1();
    }).then(function (result) {
      assert.equal(result.logs.length, 1);

      // A(a: 1, b: 3)
      var log = result.logs[0];
      assert.equal(log.event, "A");
      assert.equal(_.size(log.args), 2);
      assert.equal(log.args.a.c[0], 1);
      assert.equal(log.args.b.c[0], 3);
    });
  });

  it("should emit A(a: 1, b: 2)", async function() {
    var meta;

    await Contract.deployed().then(function(instance) {
      meta = instance;
      return meta.test2();
    }).then(function(result) {
      assert.equal(result.logs.length, 1);

      // A(a: 1, b: 2)
      var log = result.logs[0];
      assert.equal(log.event, "A");
      assert.equal(_.size(log.args), 2);
      assert.equal(log.args.a.c[0], 1);
      assert.equal(log.args.b.c[0], 2);
    });
  });

  it("should emit B(a: 1, b: 0, c: 0x0000000000000000000000000000000000000000)", async function() {
    var meta;

    await Contract.deployed().then(function(instance) {
      meta = instance;
      return meta.test3();
    }).then(function(result) {
      assert.equal(result.logs.length, 1);

      // B(a: 1, b: 0, c: 0x0000000000000000000000000000000000000000)
      var log = result.logs[0];
      assert.equal(log.event, "B");
      assert.equal(_.size(log.args), 3);
      assert.equal(log.args.a.c[0], 1);
      assert.equal(log.args.b.c[0], 0);
      assert.equal(log.args.c, '0x0000000000000000000000000000000000000000');
    });
  });

  it("should emit B(a: 1, b: 0, c: 0x0000000000000000000000000000000000000001)", async function() {
    var meta;

    await Contract.deployed().then(function(instance) {
      meta = instance;
      return meta.test4();
    }).then(function(result) {
      assert.equal(result.logs.length, 1);

      // B(a: 1, b: 0, c: 0x0000000000000000000000000000000000000001)
      var log = result.logs[0];
      assert.equal(log.event, "B");
      assert.equal(_.size(log.args), 3);
      assert.equal(log.args.a.c[0], 1);
      assert.equal(log.args.b.c[0], 0);
      assert.equal(log.args.c, '0x0000000000000000000000000000000000000001');
    });
  });

  it("should emit C(a: 420)", async function() {
    var meta;

    await Contract.deployed().then(function(instance) {
      meta = instance;
      return meta.test5();
    }).then(function(result) {
      assert.equal(result.logs.length, 1);

      // C(a: 420)
      var log = result.logs[0];
      assert.equal(log.event, "C");
      assert.equal(_.size(log.args), 1);
      assert.equal(log.args.a.c[0], 420);
    });
  });

  it("should emit D(a: 1, b: 2, c: 3, d: 4)", async function() {
    var meta;

    await Contract.deployed().then(function (instance) {
      meta = instance;
      return meta.test6();
    }).then(function (result) {
      assert.equal(result.logs.length, 1);

      // D(a: 1, b: 2, c: 3, d: 4)
      var log = result.logs[0];
      assert.equal(log.event, "D");
      assert.equal(_.size(log.args), 4);
      assert.equal(log.args.a.c[0], 1);
      assert.equal(log.args.b.c[0], 2);
      assert.equal(log.args.c.c[0], 3);
      assert.equal(log.args.d.c[0], 4);
    });
  });

  it("should emit D(a: 1, b: 2, c: 3, d: 10)", async function() {
    var meta;

    await Contract.deployed().then(function (instance) {
      meta = instance;
      return meta.test7();
    }).then(function (result) {
      assert.equal(result.logs.length, 1);

      // D(a: 1, b: 2, c: 3, d: 10)
      var log = result.logs[0];
      assert.equal(log.event, "D");
      assert.equal(_.size(log.args), 4);
      assert.equal(log.args.a.c[0], 1);
      assert.equal(log.args.b.c[0], 2);
      assert.equal(log.args.c.c[0], 3);
      assert.equal(log.args.d.c[0], 10);
    });
  });

  it("should emit D(a: 4, b: 3, c: 2, d: 1)", async function() {
    var meta;

    await Contract.deployed().then(function (instance) {
      meta = instance;
      return meta.test8();
    }).then(function (result) {
      assert.equal(result.logs.length, 1);

      // D(a: 4, b: 3, c: 2, d: 1)
      var log = result.logs[0];
      assert.equal(log.event, "D");
      assert.equal(_.size(log.args), 4);
      assert.equal(log.args.a.c[0], 4);
      assert.equal(log.args.b.c[0], 3);
      assert.equal(log.args.c.c[0], 2);
      assert.equal(log.args.d.c[0], 1);
    });
  });
});

