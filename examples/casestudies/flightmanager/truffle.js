require('dotenv').config();
const Web3 = require("web3");
const web3 = new Web3();
const WalletProvider = require("truffle-wallet-provider");
const Wallet = require('ethereumjs-wallet');
const config = require("./config.js");

var privateKey = new Buffer(config.airlinePrivateKey, "hex")
var wallet = Wallet.fromPrivateKey(privateKey);

var ropstenProvider = new WalletProvider(wallet, "https://ropsten.infura.io/");
var kovanProvider = new WalletProvider(wallet, "https://kovan.infura.io/");

module.exports = {
  networks: {
    ropsten: {
      provider: ropstenProvider,
      gas: 4600000,
      gasPrice: web3.utils.toWei("25", "gwei"),
      network_id: "3",
    },
    kovan: {
      provider: kovanProvider,
      gas: 4600000,
      gasPrice: web3.utils.toWei("25", "gwei"),
      network_id: "2",
    },
  }
};
