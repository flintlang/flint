var config = require("../config.js")

var Contract = artifacts.require("./" + config.contractName + ".sol");
var External = artifacts.require("./Returner.sol");

module.exports = function(deployer) {
  deployer.deploy(Contract);
  deployer.deploy(External);
};
