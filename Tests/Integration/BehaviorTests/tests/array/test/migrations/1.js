var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");

module.exports = function(deployer) {
  deployer.deploy(Contract);
};
